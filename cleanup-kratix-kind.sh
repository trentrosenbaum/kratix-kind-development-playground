#!/bin/bash
set -euo pipefail

# Kratix Cleanup Script for Kind Clusters
# This script removes the Kratix kind clusters

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PLATFORM_CLUSTER_NAME="platform-cluster"
WORKER_CLUSTER_NAME="worker-cluster"

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║           Kratix Cleanup Script for Kind Clusters                ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

log_warning "This will delete the following kind clusters:"
echo "  • ${PLATFORM_CLUSTER_NAME}"
echo "  • ${WORKER_CLUSTER_NAME}"
echo ""

read -p "Are you sure you want to continue? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
log_info "Starting cleanup..."
echo ""

# Delete platform cluster
if kind get clusters 2>/dev/null | grep -q "^${PLATFORM_CLUSTER_NAME}$"; then
    log_info "Deleting platform cluster: ${PLATFORM_CLUSTER_NAME}..."
    kind delete cluster --name "${PLATFORM_CLUSTER_NAME}"
    log_success "Platform cluster deleted"
else
    log_info "Platform cluster not found, skipping..."
fi

# Delete worker cluster
if kind get clusters 2>/dev/null | grep -q "^${WORKER_CLUSTER_NAME}$"; then
    log_info "Deleting worker cluster: ${WORKER_CLUSTER_NAME}..."
    kind delete cluster --name "${WORKER_CLUSTER_NAME}"
    log_success "Worker cluster deleted"
else
    log_info "Worker cluster not found, skipping..."
fi

echo ""
log_success "Cleanup complete! 🎉"
echo ""

# Show remaining clusters
REMAINING_CLUSTERS=$(kind get clusters 2>/dev/null || echo "")
if [ -n "$REMAINING_CLUSTERS" ]; then
    echo "Remaining kind clusters:"
    kind get clusters
else
    echo "No kind clusters remaining."
fi
echo ""
