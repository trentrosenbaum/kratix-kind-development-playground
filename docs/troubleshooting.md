# Troubleshooting

Common issues and their solutions when running Kratix on Kind clusters.

## Installation Issues

### Installation Fails Partway Through

**Problem:** Script fails during installation

**Solution:** Run the cleanup script and try again:

```bash
./cleanup-kratix-kind.sh
./setup-kratix-kind.sh
```

### Docker Not Running

**Problem:** Script fails with Docker-related errors

**Solution:** Ensure Docker Desktop or Docker Engine is running:

```bash
docker info
```

If this command fails, start Docker and try again.

### Insufficient Resources

**Problem:** Cluster creation fails or pods stay in Pending state

**Solution:** Ensure Docker has sufficient resources allocated:
- At least 4GB RAM recommended
- At least 2 CPUs
- Sufficient disk space

Check Docker Desktop settings or adjust Docker Engine configuration.

## Cluster Access Issues

### Can't Access Clusters

**Problem:** `kubectl` commands fail with connection errors

**Solution:** Check your context:

```bash
# List all contexts
kubectl config get-contexts

# Switch to platform cluster
kubectl config use-context kind-platform-cluster

# Or use explicit context
kubectl --context kind-platform-cluster get nodes
```

### Clusters Not Listed

**Problem:** `kind get clusters` doesn't show the clusters

**Solution:** The clusters may have been deleted. Re-run the setup:

```bash
./setup-kratix-kind.sh
```

## Workload Deployment Issues

### Worker Not Receiving Workloads

**Problem:** Promises install but resources don't appear on worker

**Solution:** Check Flux status:

```bash
# Check Flux buckets
kubectl --context $WORKER get buckets -n kratix-worker-system

# Check Flux kustomizations
kubectl --context $WORKER get kustomizations -n kratix-worker-system

# View Flux source-controller logs
kubectl --context $WORKER logs -n flux-system -l app=source-controller

# View Flux kustomize-controller logs
kubectl --context $WORKER logs -n flux-system -l app=kustomize-controller
```

### Promise Stuck in Pending

**Problem:** Promise status shows pending or not ready

**Solution:** Check the Kratix controller logs:

```bash
kubectl --context $PLATFORM logs -n kratix-platform-system \
  -l control-plane=controller-manager
```

### Pipeline Jobs Failing

**Problem:** Resource requests not being processed

**Solution:** Check pipeline job status and logs:

```bash
# List all jobs
kubectl --context $PLATFORM get jobs -A

# View logs for a specific job
kubectl --context $PLATFORM logs -f job/<job-name> -n <namespace>
```

## Network and Connectivity Issues

### MinIO Connection Issues

**Problem:** Worker can't connect to MinIO on platform cluster

**Solution:** The script uses Docker networking. Verify the platform cluster IP:

```bash
docker inspect kind-platform-cluster-control-plane | grep IPAddress
```

Check if the Flux bucket source can connect:

```bash
kubectl --context $WORKER describe bucket kratix-workload-resources -n kratix-worker-system
```

### Pods Can't Pull Images

**Problem:** Pods stuck in ImagePullBackOff

**Solution:** Check if you have network connectivity:

```bash
# Test from within a cluster
kubectl --context $PLATFORM run test --rm -it --image=busybox -- wget -qO- https://google.com
```

## Startup/Shutdown Issues

### Clusters Won't Start After Shutdown

**Problem:** `startup-kratix-kind.sh` fails or clusters are unhealthy

**Solution:** If clusters are in a bad state, clean up and recreate:

```bash
./cleanup-kratix-kind.sh
./setup-kratix-kind.sh
```

### Pods Crashing After Restart

**Problem:** Pods repeatedly crash after cluster restart

**Solution:** Wait a few minutes for everything to stabilize. Kubernetes may take time to recover. If issues persist, check pod logs:

```bash
kubectl --context $PLATFORM describe pod <pod-name> -n <namespace>
kubectl --context $PLATFORM logs <pod-name> -n <namespace>
```

## Getting More Help

### Enable Verbose Output

For more detailed script output, you can run with bash debugging:

```bash
bash -x ./setup-kratix-kind.sh
```

### Useful Debug Commands

```bash
# Get all resources in kratix namespace
kubectl --context $PLATFORM get all -n kratix-platform-system

# Describe a specific resource
kubectl --context $PLATFORM describe <resource-type> <name> -n <namespace>

# Get events (useful for troubleshooting)
kubectl --context $PLATFORM get events -n kratix-platform-system --sort-by='.lastTimestamp'

# Check node status
kubectl --context $PLATFORM get nodes -o wide
kubectl --context $WORKER get nodes -o wide
```

### External Resources

- [Kratix Documentation](https://docs.kratix.io)
- [Kratix GitHub Issues](https://github.com/syntasso/kratix/issues)
- [Kratix Slack](https://kratix.io/slack)
- [Kind Documentation](https://kind.sigs.k8s.io/docs/user/quick-start/)