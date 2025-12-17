# Create a Hello World Promise

This guide walks you through creating your first Kratix Promise from scratch. You'll build a simple Promise that provisions a ConfigMap with a greeting message to the worker cluster.

## Prerequisites

- Completed the [Quick Start Guide](quickstart.md)
- Platform and worker clusters running

## Set Environment Variables

Set the context variables for easier command execution:

```bash
export PLATFORM='kind-platform-cluster'
export WORKER='kind-worker-cluster'
```

## What You'll Build

A Promise called `greeting` that:
- Accepts a `name` parameter from users
- Creates a ConfigMap on the worker cluster with the message "Hello kratix World!!"

## Step 1: Create the Promise

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

## Step 2: Verify the Promise is Available

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

## Step 3: Create a Resource Request

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

## Step 4: Watch the Pipeline Execute

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

## Step 5: Verify the ConfigMap on the Worker

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

## Step 6: View the Message

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

Remove the greeting resource:

```bash
kubectl --context $PLATFORM delete greeting my-greeting -n default
```

Remove the Promise:

```bash
kubectl --context $PLATFORM delete promise greeting
```

The ConfigMap will be automatically removed from the worker cluster when Flux syncs.

## Next Steps

- Modify the Promise to output different Kubernetes resources
- Add validation to the API schema
- Create a custom pipeline image for more complex logic
- See [Accessing MinIO](accessing-minio.md) to view the state store contents
- Read the [Kratix documentation](https://docs.kratix.io/main/guides/writing-a-promise) for advanced Promise features