#!/bin/bash
set -euo pipefail

# Kratix Shutdown Script for Kind Clusters
# This script stops the kind clusters without destroying them
# Use for overnight/weekend suspension - clusters will recover on restart

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/config.env}"

if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=config.env
    source "${CONFIG_FILE}"
else
    echo "Warning: Config file not found at ${CONFIG_FILE}, using defaults"
    # Fallback defaults if config file is missing
    PLATFORM_CLUSTER_NAME="platform-cluster"
    WORKER_CLUSTER_NAME="worker-cluster"
fi

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

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║          Kratix Shutdown Script for Kind Clusters                ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

log_info "Stopping Kratix kind clusters..."
echo ""

# Stop worker cluster first (depends on platform)
if docker ps -q -f name="${WORKER_CLUSTER_NAME}-control-plane" | grep -q .; then
    log_info "Stopping worker cluster: ${WORKER_CLUSTER_NAME}..."
    docker stop "${WORKER_CLUSTER_NAME}-control-plane" >/dev/null
    log_success "Worker cluster stopped"
else
    if docker ps -aq -f name="${WORKER_CLUSTER_NAME}-control-plane" | grep -q .; then
        log_warning "Worker cluster is already stopped"
    else
        log_warning "Worker cluster container not found"
    fi
fi

# Stop platform cluster
if docker ps -q -f name="${PLATFORM_CLUSTER_NAME}-control-plane" | grep -q .; then
    log_info "Stopping platform cluster: ${PLATFORM_CLUSTER_NAME}..."
    docker stop "${PLATFORM_CLUSTER_NAME}-control-plane" >/dev/null
    log_success "Platform cluster stopped"
else
    if docker ps -aq -f name="${PLATFORM_CLUSTER_NAME}-control-plane" | grep -q .; then
        log_warning "Platform cluster is already stopped"
    else
        log_warning "Platform cluster container not found"
    fi
fi

echo ""
log_success "Kratix clusters have been stopped"
echo ""
echo "To restart the clusters, run: ./startup-kratix-kind.sh"
echo "To permanently delete the clusters, run: ./teardown-kratix-kind.sh"
echo ""