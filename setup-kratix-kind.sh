#!/bin/bash
set -euo pipefail

# Kratix Installation Script for Kind Clusters
# This script creates two kind clusters and installs Kratix with MinIO state store
# Platform cluster: kind-platform-cluster
# Worker cluster: kind-worker-cluster

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PLATFORM_CLUSTER_NAME="platform-cluster"
WORKER_CLUSTER_NAME="worker-cluster"
PLATFORM_CONTEXT="kind-${PLATFORM_CLUSTER_NAME}"
WORKER_CONTEXT="kind-${WORKER_CLUSTER_NAME}"
K8S_VERSION="v1.31.9"
KRATIX_VERSION="latest"

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v kind &> /dev/null; then
        missing_tools+=("kind")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Please install the missing tools:"
        echo "  - kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        echo "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
        echo "  - docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

create_platform_cluster() {
    log_info "Creating platform cluster: ${PLATFORM_CLUSTER_NAME}..."
    
    if kind get clusters 2>/dev/null | grep -q "^${PLATFORM_CLUSTER_NAME}$"; then
        log_warning "Platform cluster already exists. Deleting..."
        kind delete cluster --name "${PLATFORM_CLUSTER_NAME}"
    fi
    
    kind create cluster \
        --image "kindest/node:${K8S_VERSION}" \
        --name "${PLATFORM_CLUSTER_NAME}" \
        --wait 120s
    
    kubectl config use-context "${PLATFORM_CONTEXT}"
    log_success "Platform cluster created: ${PLATFORM_CONTEXT}"
}

create_worker_cluster() {
    log_info "Creating worker cluster: ${WORKER_CLUSTER_NAME}..."
    
    if kind get clusters 2>/dev/null | grep -q "^${WORKER_CLUSTER_NAME}$"; then
        log_warning "Worker cluster already exists. Deleting..."
        kind delete cluster --name "${WORKER_CLUSTER_NAME}"
    fi
    
    kind create cluster \
        --image "kindest/node:${K8S_VERSION}" \
        --name "${WORKER_CLUSTER_NAME}" \
        --wait 120s
    
    log_success "Worker cluster created: ${WORKER_CONTEXT}"
}

install_cert_manager() {
    log_info "Installing cert-manager on platform cluster..."
    
    kubectl --context "${PLATFORM_CONTEXT}" apply -f \
        https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
    
    log_info "Waiting for cert-manager to be ready..."
    kubectl --context "${PLATFORM_CONTEXT}" wait --for=condition=Available \
        --timeout=300s \
        -n cert-manager \
        deployment/cert-manager \
        deployment/cert-manager-cainjector \
        deployment/cert-manager-webhook
    
    log_success "cert-manager installed and ready"
}

install_kratix() {
    log_info "Installing Kratix on platform cluster..."
    
    kubectl --context "${PLATFORM_CONTEXT}" apply -f \
        "https://github.com/syntasso/kratix/releases/${KRATIX_VERSION}/download/kratix.yaml"

    log_info "Waiting for Kratix to be ready..."
    kubectl --context "${PLATFORM_CONTEXT}" wait --for=condition=Available \
        --timeout=300s \
        -n kratix-platform-system \
        deployment/kratix-platform-controller-manager
    
    log_success "Kratix installed and ready"
}

install_minio() {
    log_info "Installing MinIO as state store on platform cluster..."
    
    kubectl --context "${PLATFORM_CONTEXT}" apply -f \
        "https://raw.githubusercontent.com/syntasso/kratix/main/config/samples/minio-install.yaml"
    
    log_info "Waiting for MinIO to be ready..."
    kubectl --context "${PLATFORM_CONTEXT}" wait --for=condition=Available \
        --timeout=300s \
        -n kratix-platform-system \
        deployment/minio
    
    log_success "MinIO installed and ready"
}

configure_state_store() {
    log_info "Configuring BucketStateStore..."
    
    cat <<EOF | kubectl --context "${PLATFORM_CONTEXT}" apply -f -
apiVersion: platform.kratix.io/v1alpha1
kind: BucketStateStore
metadata:
  name: default
spec:
  endpoint: minio.kratix-platform-system.svc.cluster.local
  insecure: true
  bucketName: kratix
  secretRef:
    name: minio-credentials
    namespace: default
EOF
    
    log_success "BucketStateStore configured"
}

install_flux_on_worker() {
    log_info "Installing Flux on worker cluster..."
    
    # Install Flux (Toolkit)
    kubectl --context "${WORKER_CONTEXT}" apply -f \
        "https://raw.githubusercontent.com/syntasso/kratix/main/hack/destination/gitops-tk-install.yaml"
    
    log_info "Waiting for Flux to be ready..."
    kubectl --context "${WORKER_CONTEXT}" wait --for=condition=Available \
        --timeout=300s \
        -n flux-system \
        deployment/source-controller \
        deployment/kustomize-controller
    
    log_success "Flux installed on worker cluster"
}

configure_flux_on_worker() {
    log_info "Configuring Flux to watch MinIO on worker cluster..."
    
    # Create MinIO credentials secret on worker
    kubectl --context "${WORKER_CONTEXT}" create namespace kratix-worker-system --dry-run=client -o yaml | \
        kubectl --context "${WORKER_CONTEXT}" apply -f -
    
    # Get MinIO credentials from platform cluster
    MINIO_ACCESS_KEY=$(kubectl --context "${PLATFORM_CONTEXT}" get secret minio-credentials -n default -o jsonpath='{.data.accessKeyID}' | base64 -d)
    MINIO_SECRET_KEY=$(kubectl --context "${PLATFORM_CONTEXT}" get secret minio-credentials -n default -o jsonpath='{.data.secretAccessKey}' | base64 -d)
    
    # Get MinIO endpoint - need to use the platform cluster's IP
    PLATFORM_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${PLATFORM_CLUSTER_NAME}-control-plane")
    
    # Create secret on worker cluster (Flux expects 'accesskey' and 'secretkey')
    kubectl --context "${WORKER_CONTEXT}" create secret generic minio-credentials \
        -n kratix-worker-system \
        --from-literal=accesskey="${MINIO_ACCESS_KEY}" \
        --from-literal=secretkey="${MINIO_SECRET_KEY}" \
        --dry-run=client -o yaml | \
        kubectl --context "${WORKER_CONTEXT}" apply -f -
    
    # Create Flux Bucket source pointing to MinIO on platform cluster
    cat <<EOF | kubectl --context "${WORKER_CONTEXT}" apply -f -
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: Bucket
metadata:
  name: kratix-workload-dependencies
  namespace: kratix-worker-system
spec:
  interval: 10s
  provider: generic
  bucketName: kratix
  endpoint: ${PLATFORM_IP}:31337
  insecure: true
  secretRef:
    name: minio-credentials
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: Bucket
metadata:
  name: kratix-workload-resources
  namespace: kratix-worker-system
spec:
  interval: 10s
  provider: generic
  bucketName: kratix
  endpoint: ${PLATFORM_IP}:31337
  insecure: true
  secretRef:
    name: minio-credentials
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: kratix-workload-dependencies
  namespace: kratix-worker-system
spec:
  interval: 10s
  path: worker-cluster/dependencies
  prune: true
  sourceRef:
    kind: Bucket
    name: kratix-workload-dependencies
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: kratix-workload-resources
  namespace: kratix-worker-system
spec:
  interval: 10s
  path: worker-cluster/resources
  prune: true
  sourceRef:
    kind: Bucket
    name: kratix-workload-resources
  dependsOn:
    - name: kratix-workload-dependencies
EOF
    
    log_success "Flux configured on worker cluster"
}

register_worker_destination() {
    log_info "Registering worker cluster as a Destination..."
    
    cat <<EOF | kubectl --context "${PLATFORM_CONTEXT}" apply -f -
apiVersion: platform.kratix.io/v1alpha1
kind: Destination
metadata:
  name: worker-cluster
  labels:
    environment: dev
spec:
  path: worker-cluster
  stateStoreRef:
    name: default
    kind: BucketStateStore
EOF
    
    log_success "Worker cluster registered as Destination"
}

verify_installation() {
    log_info "Verifying installation..."
    
    echo ""
    echo "Platform Cluster Resources:"
    echo "=========================="
    kubectl --context "${PLATFORM_CONTEXT}" get pods -n kratix-platform-system
    echo ""
    kubectl --context "${PLATFORM_CONTEXT}" get bucketstatestores
    echo ""
    kubectl --context "${PLATFORM_CONTEXT}" get destinations
    
    echo ""
    echo "Worker Cluster Resources:"
    echo "========================"
    kubectl --context "${WORKER_CONTEXT}" get pods -n kratix-worker-system
    kubectl --context "${WORKER_CONTEXT}" get pods -n flux-system
    
    echo ""
    log_success "Installation verification complete"
}

print_summary() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║              Kratix Installation Complete!                        ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Cluster Information:"
    echo "  Platform Cluster: ${PLATFORM_CLUSTER_NAME}"
    echo "  Platform Context: ${PLATFORM_CONTEXT}"
    echo "  Worker Cluster:   ${WORKER_CLUSTER_NAME}"
    echo "  Worker Context:   ${WORKER_CONTEXT}"
    echo ""
    echo "Environment Variables (add to your ~/.bashrc or ~/.zshrc):"
    echo "  export PLATFORM='${PLATFORM_CONTEXT}'"
    echo "  export WORKER='${WORKER_CONTEXT}'"
    echo ""
    echo "Quick Commands:"
    echo "  # Switch to platform cluster"
    echo "  kubectl config use-context ${PLATFORM_CONTEXT}"
    echo ""
    echo "  # Switch to worker cluster"
    echo "  kubectl config use-context ${WORKER_CONTEXT}"
    echo ""
    echo "  # List available Promises"
    echo "  kubectl --context ${PLATFORM_CONTEXT} get promises"
    echo ""
    echo "  # Install a Promise from the marketplace"
    echo "  kubectl --context ${PLATFORM_CONTEXT} apply -f \\"
    echo "    https://raw.githubusercontent.com/syntasso/kratix-marketplace/main/jenkins/promise.yaml"
    echo ""
    echo "Next Steps:"
    echo "  1. Install a Promise from https://kratix.io/marketplace"
    echo "  2. Create a resource request"
    echo "  3. Watch it get deployed to the worker cluster!"
    echo ""
    echo "Documentation: https://docs.kratix.io"
    echo ""
}

cleanup_on_error() {
    log_error "Installation failed. Cleaning up..."
    
    if kind get clusters 2>/dev/null | grep -q "^${PLATFORM_CLUSTER_NAME}$"; then
        kind delete cluster --name "${PLATFORM_CLUSTER_NAME}"
    fi
    
    if kind get clusters 2>/dev/null | grep -q "^${WORKER_CLUSTER_NAME}$"; then
        kind delete cluster --name "${WORKER_CLUSTER_NAME}"
    fi
    
    exit 1
}

# Main execution
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║         Kratix Installation Script for Kind Clusters              ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "This script will:"
    echo "  • Create two kind clusters (platform and worker)"
    echo "  • Install Kratix on the platform cluster"
    echo "  • Install MinIO as the state store"
    echo "  • Install Flux on the worker cluster"
    echo "  • Register the worker as a Destination"
    echo ""
    
    # Set trap for cleanup on error
    trap cleanup_on_error ERR
    
    check_prerequisites
    
    echo ""
    log_info "Starting installation..."
    echo ""
    
    create_platform_cluster
    create_worker_cluster
    install_cert_manager
    install_kratix
    install_minio
    
    # Wait a bit for MinIO to fully initialize
    sleep 10
    
    configure_state_store
    install_flux_on_worker
    
    # Wait for Flux to be ready before configuring
    sleep 5
    
    configure_flux_on_worker
    register_worker_destination
    
    # Wait a moment for everything to settle
    sleep 5
    
    verify_installation
    print_summary
    
    log_success "All done! 🎉"
}

# Run main function
main "$@"
