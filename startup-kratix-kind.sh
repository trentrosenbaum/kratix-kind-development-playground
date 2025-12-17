#!/bin/bash
set -euo pipefail

# Kratix Startup Script for Kind Clusters
# This script starts previously stopped kind clusters
# Clusters may take 30-60 seconds to fully recover after restart

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PLATFORM_CLUSTER_NAME="platform-cluster"
WORKER_CLUSTER_NAME="worker-cluster"
PLATFORM_CONTEXT="kind-${PLATFORM_CLUSTER_NAME}"
WORKER_CONTEXT="kind-${WORKER_CLUSTER_NAME}"

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

wait_for_cluster() {
    local context=$1
    local timeout=120
    local elapsed=0

    while ! kubectl --context "$context" get nodes &>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            log_error "Timeout waiting for cluster $context to be ready"
            return 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    return 0
}

wait_for_pods() {
    local context=$1
    local namespace=$2
    local timeout=180
    local elapsed=0

    log_info "Waiting for pods in $namespace to be ready..."
    while true; do
        # Count pods not in Running/Completed state, trim whitespace from wc output
        local not_ready
        not_ready=$(kubectl --context "$context" get pods -n "$namespace" --no-headers 2>/dev/null | grep -cv "Running\|Completed" | tr -d '[:space:]')

        # Default to 0 if empty
        not_ready=${not_ready:-0}

        if [ "$not_ready" -eq 0 ] 2>/dev/null; then
            return 0
        fi

        if [ "$elapsed" -ge "$timeout" ]; then
            log_warning "Some pods may still be starting up"
            return 0
        fi

        sleep 5
        elapsed=$((elapsed + 5))
    done
}

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║           Kratix Startup Script for Kind Clusters                ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

log_info "Starting Kratix kind clusters..."
echo ""

# Check if clusters exist
PLATFORM_EXISTS=$(docker ps -aq -f name="${PLATFORM_CLUSTER_NAME}-control-plane")
WORKER_EXISTS=$(docker ps -aq -f name="${WORKER_CLUSTER_NAME}-control-plane")

if [ -z "$PLATFORM_EXISTS" ] || [ -z "$WORKER_EXISTS" ]; then
    log_error "One or both clusters do not exist."
    echo ""
    echo "Please run ./setup-kratix-kind.sh to create the clusters first."
    exit 1
fi

# Start platform cluster first
if docker ps -q -f name="${PLATFORM_CLUSTER_NAME}-control-plane" | grep -q .; then
    log_warning "Platform cluster is already running"
else
    log_info "Starting platform cluster: ${PLATFORM_CLUSTER_NAME}..."
    docker start "${PLATFORM_CLUSTER_NAME}-control-plane" >/dev/null
    log_info "Waiting for platform cluster to be ready..."
    if wait_for_cluster "$PLATFORM_CONTEXT"; then
        log_success "Platform cluster started"
    fi
fi

# Start worker cluster
if docker ps -q -f name="${WORKER_CLUSTER_NAME}-control-plane" | grep -q .; then
    log_warning "Worker cluster is already running"
else
    log_info "Starting worker cluster: ${WORKER_CLUSTER_NAME}..."
    docker start "${WORKER_CLUSTER_NAME}-control-plane" >/dev/null
    log_info "Waiting for worker cluster to be ready..."
    if wait_for_cluster "$WORKER_CONTEXT"; then
        log_success "Worker cluster started"
    fi
fi

echo ""
log_info "Waiting for Kubernetes components to recover..."

# Wait for critical pods to be ready
wait_for_pods "$PLATFORM_CONTEXT" "kratix-platform-system"
wait_for_pods "$WORKER_CONTEXT" "flux-system"

# Show cluster status
echo ""
echo "Platform Cluster Status:"
echo "========================"
kubectl --context "$PLATFORM_CONTEXT" get pods -n kratix-platform-system 2>/dev/null || echo "  Pods not ready yet"

echo ""
echo "Worker Cluster Status:"
echo "====================="
kubectl --context "$WORKER_CONTEXT" get pods -n flux-system 2>/dev/null || echo "  Pods not ready yet"

echo ""
log_success "Kratix clusters are running"
echo ""
echo "Quick Commands:"
echo "  kubectl --context ${PLATFORM_CONTEXT} get promises"
echo "  kubectl --context ${WORKER_CONTEXT} get pods --all-namespaces"
echo ""