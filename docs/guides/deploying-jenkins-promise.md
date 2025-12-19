# Deploying the Jenkins Promise

This guide walks you through deploying the Jenkins Promise from the Kratix marketplace. You'll install the Promise on the platform cluster and create a Jenkins instance that gets deployed to the worker cluster.

## Prerequisites

- Completed the [Quick Start Guide](quickstart.md)
- Platform and worker clusters running

Verify your clusters are running:

```bash
kubectl --context kind-platform-cluster get pods -n kratix-platform-system
kubectl --context kind-worker-cluster get pods -n flux-system
```

## Set Environment Variables

If you haven't already, set the context variables:

```bash
export PLATFORM='kind-platform-cluster'
export WORKER='kind-worker-cluster'
```

## Install the Jenkins Promise

Install the Jenkins Promise from the marketplace:

```bash
kubectl --context $PLATFORM apply -f \
  https://raw.githubusercontent.com/syntasso/kratix-marketplace/main/jenkins/promise.yaml
```

Wait for it to be available:

```bash
kubectl --context $PLATFORM get promises --watch
```

You should see:

```
NAME      STATUS      KIND      API VERSION                      VERSION
jenkins   Available   jenkins   marketplace.kratix.io/v1alpha1
```

Press `Ctrl+C` to exit the watch.

## Request a Jenkins Instance

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

Watch the pipeline execute on the platform cluster:

```bash
kubectl --context $PLATFORM get pods -n default --watch
```

Then watch it get deployed to the worker:

```bash
kubectl --context $WORKER get pods --all-namespaces --watch
```

It may take a few minutes for all Jenkins components to be ready.

## Access Jenkins

Port-forward to access Jenkins in your browser:

```bash
kubectl --context $WORKER port-forward svc/jenkins-operator-http-dev-example -n default 8080:8080
```

Get the Jenkins credentials:

```bash
kubectl --context $WORKER get secrets --selector app=jenkins-operator -o go-template='{{range .items}}{{"username: "}}{{.data.user|base64decode}}{{"\n"}}{{"password: "}}{{.data.password|base64decode}}{{"\n"}}{{end}}'
```

Open Jenkins at [http://localhost:8080](http://localhost:8080) and log in with the credentials above.

## Verification Commands

### Check the Promise

```bash
# View installed Promises
kubectl --context $PLATFORM get promises

# View Promise details
kubectl --context $PLATFORM describe promise jenkins
```

### Check the Resource Request

```bash
# View Jenkins requests
kubectl --context $PLATFORM get jenkins -n default

# View request details
kubectl --context $PLATFORM describe jenkins example -n default
```

### Check the Worker Deployment

```bash
# View Jenkins pods
kubectl --context $WORKER get pods -n default

# View all Jenkins resources
kubectl --context $WORKER get all -n default -l app=jenkins-operator
```

## Cleanup

Remove the Jenkins instance:

```bash
kubectl --context $PLATFORM delete jenkins example -n default
```

Remove the Promise:

```bash
kubectl --context $PLATFORM delete promise jenkins
```

The Jenkins resources will be automatically removed from the worker cluster when Flux syncs.

## Next Steps

- Browse more Promises at https://kratix.io/marketplace
- [Accessing MinIO](accessing-minio.md) - View the state store contents
- Read about [Writing Promises](https://docs.kratix.io/main/guides/writing-a-promise) to create your own
- See [FAQ](../faq.md) for common questions
- Check [Troubleshooting](../troubleshooting.md) if you encounter issues
