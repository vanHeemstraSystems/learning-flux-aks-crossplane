# 04 - Install Crossplane

## Overview

This guide walks you through installing Crossplane on your management AKS cluster using Flux GitOps. Crossplane extends Kubernetes with the ability to provision and manage Azure cloud resources using declarative APIs.

## Prerequisites

Before proceeding, ensure you have completed:

- ✅ [01 - Prerequisites](./01-prerequisites.md)
- ✅ [02 - Bootstrap Cluster](./02-bootstrap-cluster.md)
- ✅ [03 - Install Flux](./03-install-flux.md)

Verify your setup:

```bash
# Check cluster connectivity
kubectl cluster-info

# Verify Flux is running
flux check

# View Flux sources
flux get sources git
```

## What is Crossplane?

Crossplane is an open-source Kubernetes add-on that transforms your cluster into a universal control plane for managing cloud infrastructure.

### Key Capabilities

- **Provision Azure Resources**: Create and manage AKS, VNets, Storage, etc. using Kubernetes manifests
- **Composition Engine**: Build reusable infrastructure components
- **Provider Ecosystem**: Support for Azure, AWS, GCP, and more
- **GitOps Native**: Perfect integration with Flux CD

### Architecture

```
┌──────────────────────────────────────────────────┐
│           Management AKS Cluster                  │
│                                                   │
│  ┌─────────┐         ┌──────────────┐           │
│  │  Flux   │────────▶│  Crossplane  │           │
│  │Controllers        │  Controllers │           │
│  └─────────┘         └──────┬───────┘           │
│       │                      │                    │
│       │ Git Sync             │ Azure API          │
└───────┼──────────────────────┼────────────────────┘
        ▼                      ▼
  ┌───────────┐        ┌──────────────┐
  │    Git    │        │ Azure Cloud  │
  │ Repository│        │  Resources   │
  └───────────┘        └──────────────┘
```

## Installation via Flux (GitOps Method)

### Step 1: Create Crossplane Namespace

Create the file `infrastructure/crossplane/namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: crossplane-system
  labels:
    app.kubernetes.io/name: crossplane
    app.kubernetes.io/component: infrastructure
```

### Step 2: Add Crossplane Helm Repository

Create `infrastructure/crossplane/helmrepo.yaml`:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: crossplane-stable
  namespace: crossplane-system
spec:
  interval: 5m0s
  url: https://charts.crossplane.io/stable
```

### Step 3: Create Crossplane HelmRelease

Create `infrastructure/crossplane/helmrelease.yaml`:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: crossplane
  namespace: crossplane-system
spec:
  interval: 5m0s
  chart:
    spec:
      chart: crossplane
      version: '1.14.5'
      sourceRef:
        kind: HelmRepository
        name: crossplane-stable
        namespace: crossplane-system
      interval: 1m0s
  install:
    crds: CreateReplace
    remediation:
      retries: 3
  upgrade:
    crds: CreateReplace
    remediation:
      retries: 3
  values:
    # Enable composition functions
    args:
      - --enable-composition-functions
      - --enable-composition-webhook-schema-validation
    
    # Resource limits for production
    resourcesCrossplane:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 256Mi
    
    resourcesRBACManager:
      limits:
        cpu: 200m
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 128Mi
```

### Step 4: Create Kustomization File

Create `infrastructure/crossplane/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: crossplane-system

resources:
  - namespace.yaml
  - helmrepo.yaml
  - helmrelease.yaml
```

### Step 5: Configure Flux to Deploy Crossplane

Create `clusters/management/infrastructure.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./infrastructure/crossplane
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: true
  timeout: 5m0s
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: crossplane
      namespace: crossplane-system
    - apiVersion: apps/v1
      kind: Deployment
      name: crossplane-rbac-manager
      namespace: crossplane-system
```

### Step 6: Commit and Deploy

```bash
# Add all infrastructure files
git add infrastructure/crossplane/
git add clusters/management/infrastructure.yaml

# Commit
git commit -m "feat: install Crossplane via Flux"

# Push to trigger deployment
git push
```

### Step 7: Monitor Deployment

```bash
# Watch Flux reconciliation
flux get kustomizations --watch

# Watch Crossplane pods come up
kubectl get pods -n crossplane-system --watch

# Check HelmRelease status
flux get helmreleases -n crossplane-system
```

Expected output after 2-3 minutes:

```
NAME                                     READY   STATUS    AGE
crossplane-7d5fff7f7c-xxxxx             1/1     Running   2m
crossplane-rbac-manager-5b6c7d5b7-xxxxx 1/1     Running   2m
```

## Verification

### 1. Check Crossplane Deployment

```bash
# View Crossplane pods
kubectl get pods -n crossplane-system

# Check Crossplane version
kubectl get deployment crossplane -n crossplane-system \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# View Crossplane logs
kubectl logs -n crossplane-system deployment/crossplane --tail=50
```

### 2. Verify CRDs Installation

```bash
# List Crossplane CRDs
kubectl get crds | grep crossplane

# Expected CRDs:
# compositeresourcedefinitions.apiextensions.crossplane.io
# compositions.apiextensions.crossplane.io
# providers.pkg.crossplane.io
# providerconfigs.pkg.crossplane.io
```

### 3. Test Crossplane Status

```bash
# Get detailed deployment info
kubectl describe deployment crossplane -n crossplane-system

# Check for any errors
kubectl get events -n crossplane-system --sort-by='.lastTimestamp'
```

## Understanding Crossplane Components

### Core Components

**1. Crossplane Controller**

- Reconciles composite resources
- Manages provider lifecycle
- Handles resource composition

**2. RBAC Manager**

- Manages provider permissions
- Creates service accounts
- Configures role bindings

**3. Package Manager**

- Installs providers and configurations
- Manages dependencies
- Handles version upgrades

### Resource Hierarchy

```
Provider (e.g., provider-azure)
    ↓
ProviderConfig (authentication)
    ↓
Managed Resources (ResourceGroup, VNet, AKS)
    ↓
Composite Resource Definition (XRD)
    ↓
Composition (infrastructure patterns)
    ↓
Claims (developer-friendly APIs)
```

## Troubleshooting

### Issue: Pods Not Starting

```bash
# Check pod events
kubectl describe pod -n crossplane-system <pod-name>

# View logs
kubectl logs -n crossplane-system deployment/crossplane

# Common causes:
# - Image pull errors
# - Resource constraints
# - CRD conflicts from previous installations
```

### Issue: HelmRelease Failing

```bash
# Check HelmRelease status
kubectl describe helmrelease crossplane -n crossplane-system

# View Helm controller logs
kubectl logs -n flux-system deployment/helm-controller

# Force reconciliation
flux reconcile helmrelease crossplane -n crossplane-system
```

### Issue: CRDs Not Installing

```bash
# Verify CRDs exist
kubectl get crds | grep crossplane

# Check if install.crds is set
kubectl get helmrelease crossplane -n crossplane-system -o yaml | grep crds
```

## Best Practices

### 1. Pin Versions in Production

```yaml
spec:
  chart:
    spec:
      version: '1.14.5'  # Not '>=1.14.0' or '*'
```

### 2. Enable Monitoring

```yaml
values:
  metrics:
    enabled: true
  serviceMonitor:
    enabled: true  # If using Prometheus Operator
```

### 3. Configure High Availability

For production clusters:

```yaml
values:
  replicas: 3
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app.kubernetes.io/name: crossplane
          topologyKey: kubernetes.io/hostname
```

### 4. Regular Backups

```bash
# Backup Crossplane resources
kubectl get providers -A -o yaml > backup-providers.yaml
kubectl get providerconfigs -A -o yaml > backup-providerconfigs.yaml
kubectl get compositions -A -o yaml > backup-compositions.yaml
```

## Next Steps

With Crossplane installed, you’re ready to configure the Azure provider:

👉 **[05 - Configure Azure Provider](./05-configure-azure-provider.md)**

This will cover:

- Installing Azure Provider family
- Creating service principal
- Configuring authentication
- Testing provider connectivity

## Additional Resources

- [Crossplane Documentation](https://docs.crossplane.io/)
- [Crossplane Concepts](https://docs.crossplane.io/latest/concepts/)
- [GitOps with Crossplane](https://docs.crossplane.io/knowledge-base/guides/continuous-delivery/)

-----

*Estimated time: 20-30 minutes*
