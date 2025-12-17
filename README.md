# Kratix Kind Setup

Automated scripts for setting up Kratix on Kind clusters with a platform/worker architecture.

## Overview

This project provides scripts to create a complete local Kratix environment:

- **Platform Cluster** - Where Kratix runs and Promises are defined
- **Worker Cluster** - Where workloads are deployed
- **MinIO** - S3-compatible state store for GitOps
- **Flux CD** - GitOps agent on worker cluster

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) - Docker Desktop or Docker Engine
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) - Kubernetes in Docker
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes CLI

## Quick Start

```bash
# Install Kratix on Kind clusters
./setup-kratix-kind.sh

# Set environment variables
export PLATFORM='kind-platform-cluster'
export WORKER='kind-worker-cluster'
```

See the [Quick Start Guide](docs/quickstart.md) for detailed instructions and examples.

## Scripts

| Script | Description |
|--------|-------------|
| `setup-kratix-kind.sh` | Create clusters and install Kratix (~5-7 minutes) |
| `shutdown-kratix-kind.sh` | Stop clusters without deleting them |
| `startup-kratix-kind.sh` | Start previously stopped clusters |
| `cleanup-kratix-kind.sh` | Delete clusters and all resources |

## Documentation

- [Quick Start Guide](docs/quickstart.md) - Installation and first Promise
- [FAQ](docs/faq.md) - Common questions and answers
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## Configuration Reference

### Clusters

| Cluster | Name | Context |
|---------|------|---------|
| Platform | `platform-cluster` | `kind-platform-cluster` |
| Worker | `worker-cluster` | `kind-worker-cluster` |

### Namespaces

| Component | Namespace |
|-----------|-----------|
| Kratix | `kratix-platform-system` |
| MinIO | `kratix-platform-system` |
| Flux | `flux-system` |
| Worker Resources | `kratix-worker-system` |

### State Store

- **Type**: BucketStateStore (MinIO)
- **Bucket**: `kratix`
- **Destination Path**: `worker-cluster`

## Tips

Use aliases for quick context switching:

```bash
alias kp='kubectl --context kind-platform-cluster'
alias kw='kubectl --context kind-worker-cluster'
```

## Links

- [Kratix Documentation](https://docs.kratix.io)
- [Kratix Marketplace](https://kratix.io/marketplace)
- [Kratix GitHub](https://github.com/syntasso/kratix)
- [Kind Documentation](https://kind.sigs.k8s.io)

## License

Apache 2.0