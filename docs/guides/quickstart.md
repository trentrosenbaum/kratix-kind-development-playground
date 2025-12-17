# Quick Start Guide

This guide walks you through setting up Kratix on Kind clusters and deploying your first Promise.

## Prerequisites

Make sure you have these installed:

- **Docker** - Docker Desktop or Docker Engine running
- **kind** - Kubernetes in Docker
- **kubectl** - Kubernetes CLI

Installation links:
- Docker: https://docs.docker.com/get-docker/
- kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation
- kubectl: https://kubernetes.io/docs/tasks/tools/

## Install Kratix

Run the setup script:

```bash
./setup-kratix-kind.sh
```

The script will:
1. Check prerequisites
2. Create platform cluster
3. Create worker cluster
4. Install cert-manager
5. Install Kratix
6. Install MinIO state store
7. Configure Flux on worker
8. Register worker as Destination
9. Verify everything is working

**Total time: ~5-7 minutes**

## Set Environment Variables

After installation, add these to your shell profile (`~/.bashrc` or `~/.zshrc`):

```bash
export PLATFORM='kind-platform-cluster'
export WORKER='kind-worker-cluster'
```

## Install Your First Promise

Install the Jenkins Promise from the marketplace:

```bash
kubectl --context $PLATFORM apply -f \
  https://raw.githubusercontent.com/syntasso/kratix-marketplace/main/jenkins/promise.yaml
```

Wait for it to be available:

```bash
kubectl --context $PLATFORM get promises --watch
```

## Request a Resource

Create a Jenkins instance:

```bash
cat <<EOF | kubectl --context $PLATFORM apply -f -
apiVersion: marketplace.kratix.io/v1alpha1
kind: jenkins
metadata:
  name: example
  namespace: default
spec:
  env: dev
EOF
```

Watch it get deployed to the worker:

```bash
kubectl --context kind-worker-cluster get pods --all-namespaces --watch
```

## Access Jenkins

Port-forward to access Jenkins in your browser:

```bash
kubectl --context kind-worker-cluster port-forward svc/jenkins-operator-http-dev-example -n default 8080:8080
```

Get the Jenkins credentials:

```bash
kubectl --context kind-worker-cluster get secrets --selector app=jenkins-operator -o go-template='{{range .items}}{{"username: "}}{{.data.user|base64decode}}{{"\n"}}{{"password: "}}{{.data.password|base64decode}}{{"\n"}}{{end}}'
```

Open Jenkins at [http://localhost:8080](http://localhost:8080) and log in with the credentials above.

## Verification Commands

### Check Platform Cluster

```bash
# View Kratix controller
kubectl --context $PLATFORM get pods -n kratix-platform-system

# View MinIO
kubectl --context $PLATFORM get pods -n kratix-platform-system | grep minio

# View Destinations
kubectl --context $PLATFORM get destinations

# View Promises
kubectl --context $PLATFORM get promises
```

### Check Worker Cluster

```bash
# View Flux
kubectl --context $WORKER get pods -n flux-system

# View Kratix worker components
kubectl --context $WORKER get pods -n kratix-worker-system

# View deployed workloads
kubectl --context $WORKER get pods --all-namespaces
```

## Cleanup

To remove the Kind clusters and all resources:

```bash
./teardown-kratix-kind.sh
```

## Next Steps

- Browse available Promises at https://kratix.io/marketplace
- Read about [Writing Promises](https://docs.kratix.io/main/guides/writing-a-promise)
- See [FAQ](../faq.md) for common questions
- Check [Troubleshooting](../troubleshooting.md) if you encounter issues