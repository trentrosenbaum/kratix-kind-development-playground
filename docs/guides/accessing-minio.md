# Accessing MinIO

This guide shows you how to browse the MinIO state store to see the manifests that Flux pulls down to the worker cluster.

## Prerequisites

- Completed the [Quick Start Guide](quickstart.md)
- Platform cluster running with MinIO deployed

## Install MinIO Client

The Kratix MinIO installation only exposes the S3 API, not the web console. Use the MinIO Client (`mc`) to browse contents.

### macOS

```bash
brew install minio/stable/mc
```

### Linux

```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/
```

## Connect to MinIO

Start port-forwarding to the MinIO service:

```bash
kubectl --context kind-platform-cluster port-forward -n kratix-platform-system svc/minio 9000:80
```

In a new terminal, get the MinIO credentials and configure mc:

```bash
# Get credentials
ACCESS_KEY=$(kubectl --context kind-platform-cluster get secret minio-credentials -n default -o jsonpath='{.data.accessKeyID}' | base64 -d)
SECRET_KEY=$(kubectl --context kind-platform-cluster get secret minio-credentials -n default -o jsonpath='{.data.secretAccessKey}' | base64 -d)

# Configure mc alias
mc alias set kratix http://localhost:9000 "$ACCESS_KEY" "$SECRET_KEY"
```

## Browse State Store Contents

### List Buckets

```bash
mc ls kratix
```

### List Bucket Contents

The `kratix` bucket contains the manifests organized by destination:

```bash
mc ls kratix/kratix
```

### View Destination Resources

To see what will be deployed to a specific destination (e.g., the worker cluster):

```bash
# List all resources for the worker destination
mc ls kratix/kratix/worker-cluster/

# List resources including subdirectories
mc ls kratix/kratix/worker-cluster/ --recursive
```

### View a Specific Manifest

```bash
mc cat kratix/kratix/worker-cluster/path/to/manifest.yaml
```

## Understanding the State Store Structure

The MinIO bucket structure follows this pattern:

```
kratix/
└── <destination-name>/
    ├── dependencies/     # Promise dependencies (CRDs, operators, etc.)
    └── resources/        # Resource request outputs
```

- **dependencies/**: Contains manifests installed when a Promise is applied (e.g., operators, CRDs)
- **resources/**: Contains manifests generated when users request resources through Promises

## Troubleshooting

### Connection Refused

Ensure the port-forward is running:

```bash
kubectl --context kind-platform-cluster port-forward -n kratix-platform-system svc/minio 9000:80
```

### Invalid Credentials

Re-fetch the credentials:

```bash
kubectl --context kind-platform-cluster get secret minio-credentials -n default -o jsonpath='{.data.accessKeyID}' | base64 -d
kubectl --context kind-platform-cluster get secret minio-credentials -n default -o jsonpath='{.data.secretAccessKey}' | base64 -d
```

### Empty Bucket

If the bucket appears empty, verify that:
1. A Promise has been installed on the platform cluster
2. The BucketStateStore is configured correctly:

```bash
kubectl --context kind-platform-cluster get bucketstatestores
```