# Brittleness Analysis Report

**Date:** 19 December 2025
**Subject:** Analysis of script brittleness related to Kratix releases

## Introduction

> How might the scripts be brittle to the release of new versions of Kratix by Syntasso?

This report examines the Kratix Kind development playground scripts to identify potential points of failure when Syntasso releases new versions of Kratix or when dependencies are updated.

---

## Overview

The analysis revealed several categories of brittleness across the setup and lifecycle management scripts, ranging from critical issues that could cause complete installation failure to lower-risk items that may cause subtle problems.

---

## Critical Issues

### 1. Hardcoded URLs (Critical Brittleness)

**Location:** `setup-kratix-kind.sh`

The script contains multiple hardcoded GitHub URLs that are brittle to changes:

#### Cert-Manager Installation (Line 114)
```bash
https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
```
**Risks:**
- Hardcoded cert-manager version (v1.13.2) will become obsolete
- URL structure assumes current GitHub release format which could change
- No validation that the URL is still accessible or the version exists
- If cert-manager introduces breaking changes, the script will fail silently or with cryptic errors

#### Kratix Installation (Line 131)
```bash
https://github.com/syntasso/kratix/releases/${KRATIX_VERSION}/download/kratix.yaml
```
**Risks:**
- Uses `${KRATIX_VERSION}` set to "latest" (line 22), which is a dangerous pattern
- If Kratix changes release URL structure or moves repositories, installation fails
- No checksum validation of downloaded manifests
- "latest" tag could download incompatible versions between script runs

#### MinIO Installation (Line 146)
```bash
https://raw.githubusercontent.com/syntasso/kratix/main/config/samples/minio-install.yaml
```
**Risks:**
- Points to `main` branch, which is volatile and can change unexpectedly
- No version pinning - if Kratix refactors this file, script breaks
- No fallback if the repository structure changes

#### Flux Installation (Line 182)
```bash
https://raw.githubusercontent.com/syntasso/kratix/main/hack/destination/gitops-tk-install.yaml
```
**Risks:**
- Points to a development path (`hack/destination`) that is not stable
- Depends on Kratix's internal directory structure
- Brittle to Kratix repository refactoring
- Uses `main` branch (volatile)

#### Marketplace Reference (Line 348)
```bash
https://raw.githubusercontent.com/syntasso/kratix-marketplace/main/jenkins/promise.yaml
```
**Risks:**
- External dependency on separate repository
- Points to `main` branch
- Example Promise may change or be removed

---

### 2. Hardcoded Version Numbers (High Risk)

**Location:** `setup-kratix-kind.sh`

#### Kubernetes Version (Line 21)
```bash
K8S_VERSION="v1.31.9"
```
**Risks:**
- Locked to specific minor version which will eventually reach EOL
- Kind may deprecate support for this version
- No mechanism to update when newer versions are recommended
- Compatibility with newer cert-manager or Kratix versions unknown

#### Cert-Manager Version (Line 114)
```bash
v1.13.2
```
**Risks:**
- No mechanism to discover or validate the latest compatible version
- Cert-manager has security updates - older versions may be insecure
- Breaking changes between minor versions (v1.13 → v1.14) not handled

---

## High Risk Issues

### 3. Kubernetes API Versions (Medium Risk)

**Location:** `setup-kratix-kind.sh`

#### Kratix v1alpha1 (Lines 161, 282)
```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: BucketStateStore
---
apiVersion: platform.kratix.io/v1alpha1
kind: Destination
```
**Risks:**
- `v1alpha1` indicates an unstable/experimental API
- Kratix may deprecate and remove `v1alpha1` in future releases
- If Kratix moves to `v1` or `v1beta1`, script will fail
- No migration path documented

#### Flux API Versions (Lines 218, 232, 246, 259)
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
apiVersion: kustomize.toolkit.fluxcd.io/v1
```
**Risks:**
- Mix of `v1beta2` and `v1` versions suggests incomplete API stabilisation
- Flux has historically deprecated older API versions
- If Flux moves past these versions, script breaks

---

### 4. Hardcoded Resource Names and Namespaces (High Risk)

**Location:** Multiple locations in `setup-kratix-kind.sh`

#### Cluster Names (Lines 17-20)
```bash
PLATFORM_CLUSTER_NAME="platform-cluster"
WORKER_CLUSTER_NAME="worker-cluster"
PLATFORM_CONTEXT="kind-${PLATFORM_CLUSTER_NAME}"
WORKER_CONTEXT="kind-${WORKER_CONTEXT}"
```
**Risks:**
- All scripts assume these exact cluster names
- No parameterisation for custom setups
- If a user wants multiple Kratix environments, they must modify scripts
- Docker container detection relies on exact naming (e.g., `platform-cluster-control-plane`)

#### Namespace Names

| Namespace | Usage | Risk |
|-----------|-------|------|
| `kratix-platform-system` | Kratix controller, MinIO | Hard-coded in multiple places; if Kratix changes namespace, all scripts fail |
| `kratix-worker-system` | Worker Flux resources | Hard-coded; Kratix dependency on specific namespace |
| `flux-system` | Flux controllers | Hard-coded; standard but assumed |
| `cert-manager` | Cert-manager (implicit) | Referenced in wait conditions but assumed to exist |
| `default` | Secret storage | MinIO credentials stored in `default` namespace (security concern) |

#### Kubernetes Resource Names (Lines 120-122, 137, 152, 188-189)
```bash
deployment/cert-manager
deployment/cert-manager-cainjector
deployment/cert-manager-webhook
deployment/kratix-platform-controller-manager
deployment/minio
deployment/source-controller
deployment/kustomize-controller
```
**Risks:**
- If component maintainers rename deployments, script's wait conditions fail
- No fallback detection mechanism
- Silently fails if deployment doesn't exist but other pods are running

---

### 5. Hardcoded Secret Names and Keys (High Risk)

**Location:** Lines 202-203

```bash
MINIO_ACCESS_KEY=$(kubectl ... get secret minio-credentials -n default -o jsonpath='{.data.accessKeyID}' | base64 -d)
MINIO_SECRET_KEY=$(kubectl ... get secret minio-credentials -n default -o jsonpath='{.data.secretAccessKey}' | base64 -d)
```
**Risks:**
- Assumes secret named exactly `minio-credentials` exists in `default` namespace
- Hardcoded JSON paths (`accessKeyID`, `secretAccessKey`)
- If Kratix's minio-install.yaml changes secret structure, script fails
- No error handling if secret doesn't exist

---

### 6. Hardcoded Flux Configuration Paths (High Risk)

**Location:** Lines 253, 266

```yaml
path: worker-cluster/dependencies
path: worker-cluster/resources
```
**Risks:**
- Assumes MinIO bucket has these exact directory structures
- Kratix's minio-install.yaml must create these paths
- If Kratix changes bucket structure, workloads won't be deployed
- No validation that paths exist

---

## Medium Risk Issues

### 7. MinIO Port Hardcoding

**Location:** Lines 227, 241

```bash
endpoint: ${PLATFORM_IP}:31337
```
**Risks:**
- Port 31337 is hardcoded for MinIO NodePort
- No validation that MinIO is actually exposed on this port
- If Kratix's minio-install.yaml changes the port, script silently fails
- No service discovery mechanism

---

### 8. Hardcoded Kubernetes DNS Names

**Location:** Line 166

```yaml
endpoint: minio.kratix-platform-system.svc.cluster.local
```
**Risks:**
- Assumes MinIO pod is named `minio` in the `kratix-platform-system` namespace
- If Kratix refactors MinIO installation, this breaks
- No validation that the service exists

---

### 9. Hardcoded Labels (Low Risk)

**Location:** Line 287

```yaml
labels:
  environment: dev
```
**Risks:**
- Hard-coded destination label `environment: dev`
- If Kratix Promise expects different labels, routing fails
- No flexibility for production configurations

---

## Installation Pattern Brittleness

**Location:** Throughout `setup-kratix-kind.sh`

### Assumption of Kratix Release Structure

The script assumes:
1. Kratix publishes releases via GitHub
2. Release assets named exactly `kratix.yaml`
3. Cert-manager publishes releases with the same URL structure
4. MinIO installation exists at `config/samples/minio-install.yaml` path
5. Flux installation exists at `hack/destination/gitops-tk-install.yaml`

If any of these assumptions change (repository move, release restructuring, filename changes), the script fails completely with no graceful degradation.

### Static Wait Conditions

Wait conditions check for specific deployments/pods:
```bash
kubectl ... wait --for=condition=Available --timeout=300s -n namespace deployment/name
```
**Risks:**
- If deployment takes >300s, installation fails
- No adaptive timeout based on system resources
- Silent failure if deployment never becomes available

### Assumption of Specific Kind Version

The script creates Kind clusters expecting:
- Kind exposes control-plane as Docker container: `${CLUSTER_NAME}-control-plane`
- Kind outputs kubeconfig in standard location: `~/.kube/config`

If Kind changes its naming or kubeconfig handling, the cluster detection fails.

---

## Critical Dependency Chain Brittleness

The script assumes a specific working sequence:
1. Cert-manager must be installed BEFORE Kratix (Kratix uses cert-manager)
2. MinIO must be installed BEFORE configuring state store
3. Flux must be installed BEFORE configuring Flux sources
4. Cluster IPs must be deterministic (Docker inspect for platform cluster IP)

**Risks:**
- No validation of dependency order
- If steps are reordered or fail partially, script continues with incorrect assumptions
- Docker inspect for cluster IP assumes single network interface

---

## Error Handling Gaps

**Location:** Throughout all scripts

**Risks:**
- `set -euo pipefail` catches most errors, but:
  - Piped commands like `base64 -d` may hide failures
  - Kubernetes API calls might succeed with empty results (silent failures)
  - Network timeouts might not be caught properly
- No validation of intermediate states (e.g., did the secret actually get created?)
- Cleanup on error deletes clusters but doesn't distinguish between partial and complete failures

---

## Summary of Risk Levels

| Category | Count | Risk Level | Impact |
|----------|-------|------------|--------|
| Hardcoded GitHub URLs | 5 | Critical | Complete installation failure |
| Hardcoded versions | 2 | High | Version mismatch, EOL software |
| API version assumptions | 2 | Medium | Future incompatibility |
| Namespace hard-coding | 4 | High | Component discovery failure |
| Resource name hard-coding | 7 | High | Wait condition failures |
| Port hard-coding | 1 | Medium | Service discovery failure |
| DNS name hard-coding | 1 | Medium | MinIO connectivity failure |
| Secret assumptions | 2 | High | Secret retrieval failure |
| Path assumptions | 2 | High | Workload deployment failure |
| Release structure assumptions | Multiple | Critical | Entire installation failure |

---

## Recommendations

1. **Create a configuration file** for versions, URLs, and customisable values
2. **Pin to specific Kratix releases** instead of `latest` or `main`
3. **Add version discovery** to fetch compatible versions
4. **Implement checksum validation** for downloaded manifests
5. **Use stable API versions** when available (move from v1alpha1)
6. **Implement service discovery** instead of hard-coded names and ports
7. **Add validation steps** between installation phases
8. **Document version compatibility matrix**
9. **Add dry-run mode** to validate configuration before applying
10. **Improve error handling** with specific error messages
