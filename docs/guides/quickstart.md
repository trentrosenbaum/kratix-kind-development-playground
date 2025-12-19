# Quick Start Guide

This guide walks you through setting up Kratix on Kind clusters and creating your first Promise from scratch. By the end, you'll have a working Kratix platform with a custom Promise that provisions resources to a worker cluster.

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

For this session, export them now:

```bash
export PLATFORM='kind-platform-cluster'
export WORKER='kind-worker-cluster'
```

## Create Your First Promise

You'll build a simple Promise called `greeting` that:
- Accepts a `name` parameter from users
- Creates a ConfigMap on the worker cluster with a greeting message

### Step 1: Create the Promise

Apply the Promise definition to the platform cluster:

```bash
kubectl --context $PLATFORM apply -f - <<'EOF'
apiVersion: platform.kratix.io/v1alpha1
kind: Promise
metadata:
  name: greeting
spec:
  api:
    apiVersion: apiextensions.k8s.io/v1
    kind: CustomResourceDefinition
    metadata:
      name: greetings.example.promise.syntasso.io
    spec:
      group: example.promise.syntasso.io
      names:
        kind: greeting
        plural: greetings
        singular: greeting
      scope: Namespaced
      versions:
        - name: v1
          served: true
          storage: true
          schema:
            openAPIV3Schema:
              type: object
              properties:
                spec:
                  type: object
                  properties:
                    name:
                      type: string
                      description: "Name to include in the greeting"
                      default: "World"
  workflows:
    resource:
      configure:
        - apiVersion: platform.kratix.io/v1alpha1
          kind: Pipeline
          metadata:
            name: greeting-pipeline
          spec:
            containers:
              - name: create-configmap
                image: busybox
                command:
                  - sh
                  - -c
                  - |
                    name=$(cat /kratix/input/object.yaml | grep -A1 "spec:" | grep "name:" | awk '{print $2}')
                    name=${name:-World}
                    lowername=$(echo "$name" | tr '[:upper:]' '[:lower:]')
                    cat <<YAML > /kratix/output/configmap.yaml
                    apiVersion: v1
                    kind: ConfigMap
                    metadata:
                      name: greeting-${lowername}
                      namespace: default
                    data:
                      message: "Hello kratix World!!"
                      greeting: "Hello, ${name}!"
                    YAML
EOF
```

### Step 2: Verify the Promise is Available

Wait for the Promise to be ready:

```bash
kubectl --context $PLATFORM get promises --watch
```

You should see:

```
NAME       STATUS      KIND       API VERSION                         VERSION
greeting   Available   greeting   example.promise.syntasso.io/v1      v1
```

Press `Ctrl+C` to exit the watch.

### Step 3: Create a Resource Request

Request a greeting resource:

```bash
kubectl --context $PLATFORM apply -f - <<'EOF'
apiVersion: example.promise.syntasso.io/v1
kind: greeting
metadata:
  name: my-greeting
  namespace: default
spec:
  name: Kratix
EOF
```

### Step 4: Watch the Pipeline Execute

Check the pipeline job on the platform cluster:

```bash
kubectl --context $PLATFORM get pods -n default --watch
```

You should see a pipeline pod run to completion:

```
NAME                                     READY   STATUS      RESTARTS   AGE
kratix-greeting-my-greeting-xxxxx        0/1     Completed   0          30s
```

Press `Ctrl+C` to exit the watch.

### Step 5: Verify the ConfigMap on the Worker

Wait for Flux to sync the ConfigMap to the worker cluster (this may take up to a minute):

```bash
kubectl --context $WORKER get configmap greeting-kratix -n default --watch
```

Once it appears, view the ConfigMap contents:

```bash
kubectl --context $WORKER get configmap greeting-kratix -n default -o yaml
```

You should see:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: greeting-kratix
  namespace: default
data:
  message: "Hello kratix World!!"
  greeting: "Hello, Kratix!"
```

### Step 6: View the Message

Extract just the message:

```bash
kubectl --context $WORKER get configmap greeting-kratix -n default -o jsonpath='{.data.message}'
```

Output:

```
Hello kratix World!!
```

## How It Works

1. **Promise Definition**: Defines the API (CRD) that users interact with and the workflow pipeline
2. **Resource Request**: Users create a `greeting` resource with their desired `name`
3. **Pipeline Execution**: Kratix runs the pipeline container which reads the request and generates the ConfigMap YAML
4. **State Store**: The generated manifest is written to MinIO
5. **Flux Sync**: Flux detects the new manifest and applies it to the worker cluster

## Cleanup

Remove the greeting resource and Promise:

```bash
kubectl --context $PLATFORM delete greeting my-greeting -n default
kubectl --context $PLATFORM delete promise greeting
```

The ConfigMap will be automatically removed from the worker cluster when Flux syncs.

To remove the Kind clusters entirely:

```bash
./teardown-kratix-kind.sh
```

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

## Next Steps

- [Deploying the Jenkins Promise](deploying-jenkins-promise.md) - Deploy a real-world application from the marketplace
- [Accessing MinIO](accessing-minio.md) - Browse the MinIO state store to view manifests
- Browse available Promises at https://kratix.io/marketplace
- Read about [Writing Promises](https://docs.kratix.io/main/guides/writing-a-promise) for advanced features
- See [FAQ](../faq.md) for common questions
- Check [Troubleshooting](../troubleshooting.md) if you encounter issues
