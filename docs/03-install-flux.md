# 03 - Install Flux

## Overview

This guide walks you through bootstrapping Flux CD on your management AKS cluster, configuring GitOps workflows, and deploying your first application using declarative Git-based deployments.

## Prerequisites

Before proceeding, ensure:

- ✅ Management AKS cluster is running ([02 - Bootstrap Cluster](./02-bootstrap-cluster.md))
- ✅ kubectl is configured to access the cluster
- ✅ Flux CLI is installed
- ✅ GitHub token and user are set in environment variables

Verify your setup:

```bash
# Check cluster access
kubectl cluster-info
kubectl get nodes

# Check Flux prerequisites
flux check --pre

# Verify environment variables
echo $GITHUB_TOKEN | cut -c1-10  # Should show: ghp_xxxxx
echo $GITHUB_USER
```

## What is Flux?

Flux is a GitOps operator for Kubernetes that keeps your clusters in sync with configuration stored in Git repositories.

### Core Concepts

**GitOps Principles**:

1. **Declarative**: System state described declaratively
1. **Versioned**: Canonical state stored in Git
1. **Automated**: Software agents pull desired state
1. **Continuously Reconciled**: Actual and desired state continuously aligned

**Flux Architecture**:

```
┌─────────────────────────────────────────────────┐
│         Git Repository (Source of Truth)        │
│  ├── clusters/management/                       │
│  ├── infrastructure/                            │
│  └── applications/                              │
└────────────┬────────────────────────────────────┘
             │ Sync
             ▼
┌─────────────────────────────────────────────────┐
│         AKS Management Cluster                   │
│  ┌───────────────────────────────────────┐     │
│  │        Flux Controllers                │     │
│  │  ┌─────────────────────────────────┐  │     │
│  │  │  • Source Controller            │  │     │
│  │  │    (Git, Helm, Bucket)          │  │     │
│  │  │  • Kustomize Controller         │  │     │
│  │  │    (Apply manifests)            │  │     │
│  │  │  • Helm Controller              │  │     │
│  │  │    (Helm releases)              │  │     │
│  │  │  • Notification Controller      │  │     │
│  │  │    (Alerts, events)             │  │     │
│  │  └─────────────────────────────────┘  │     │
│  └───────────────────────────────────────┘     │
│                      ↓                          │
│         Kubernetes Resources                    │
│  (Deployments, Services, ConfigMaps, etc.)     │
└─────────────────────────────────────────────────┘
```

### Flux Components

1. **Source Controller**: Manages Git repositories, Helm repositories, and S3 buckets
1. **Kustomize Controller**: Reconciles Kubernetes manifests using Kustomize
1. **Helm Controller**: Manages Helm releases
1. **Notification Controller**: Sends alerts and receives webhooks
1. **Image Reflector/Automation Controllers**: Automate image updates

-----

## Bootstrap Flux

### Step 1: Set GitHub Variables

```bash
# GitHub configuration
export GITHUB_TOKEN="your-github-token"
export GITHUB_USER="your-github-username"
export GITHUB_REPO="learning-flux-aks-crossplane"

# Verify
echo "User: $GITHUB_USER"
echo "Repo: $GITHUB_REPO"
echo "Token: ${GITHUB_TOKEN:0:10}..."
```

### Step 2: Bootstrap Flux

```bash
# Bootstrap Flux on the cluster
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=./clusters/management \
  --personal \
  --components-extra=image-reflector-controller,image-automation-controller
```

This command will:

1. Create the GitHub repository (if it doesn’t exist)
1. Install Flux components on the cluster
1. Configure deploy keys for Git access
1. Create initial Flux manifests in the repo
1. Commit and push the configuration

**Expected output**:

```
► connecting to github.com
✔ repository "https://github.com/$GITHUB_USER/$GITHUB_REPO" created
► cloning branch "main" from Git repository "https://github.com/$GITHUB_USER/$GITHUB_REPO.git"
✔ cloned repository
► generating component manifests
✔ generated component manifests
✔ committed sync manifests to "main" ("abc123")
► pushing component manifests to "https://github.com/$GITHUB_USER/$GITHUB_REPO.git"
✔ installed components
✔ reconciled components
► determining if source secret "flux-system/flux-system" exists
► generating source secret
✔ public key: ssh-rsa AAAA...
✔ configured deploy key "flux-system-main-flux-system-./clusters/management" for "https://github.com/$GITHUB_USER/$GITHUB_REPO"
► applying source secret "flux-system/flux-system"
✔ reconciled source secret
► generating sync manifests
✔ generated sync manifests
✔ committed sync manifests to "main" ("def456")
► pushing sync manifests to "https://github.com/$GITHUB_USER/$GITHUB_REPO.git"
► applying sync manifests
✔ reconciled sync configuration
◎ waiting for GitRepository "flux-system/flux-system" to be reconciled
✔ GitRepository reconciled successfully
◎ waiting for Kustomization "flux-system/flux-system" to be reconciled
✔ Kustomization reconciled successfully
► confirming components are healthy
✔ helm-controller: deployment ready
✔ kustomize-controller: deployment ready
✔ notification-controller: deployment ready
✔ source-controller: deployment ready
✔ image-reflector-controller: deployment ready
✔ image-automation-controller: deployment ready
✔ all components are healthy
```

### Step 3: Verify Installation

```bash
# Check Flux components
flux check

# View all Flux resources
flux get all

# Check Flux pods
kubectl get pods -n flux-system
```

Expected pods:

```
NAME                                           READY   STATUS    AGE
helm-controller-xxx                            1/1     Running   2m
image-automation-controller-xxx                1/1     Running   2m
image-reflector-controller-xxx                 1/1     Running   2m
kustomize-controller-xxx                       1/1     Running   2m
notification-controller-xxx                    1/1     Running   2m
source-controller-xxx                          1/1     Running   2m
```

-----

## Understanding the Repository Structure

After bootstrap, your repository will have this structure:

```
learning-flux-aks-crossplane/
├── clusters/
│   └── management/
│       ├── flux-system/
│       │   ├── gotk-components.yaml     # Flux components
│       │   ├── gotk-sync.yaml           # Git sync configuration
│       │   └── kustomization.yaml       # Kustomization for Flux
│       └── README.md
└── README.md
```

### Key Files

**`gotk-components.yaml`**: Contains all Flux CRDs and deployments (auto-generated)

**`gotk-sync.yaml`**: Defines the GitRepository and Kustomization that keeps the cluster in sync

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m0s
  ref:
    branch: main
  secretRef:
    name: flux-system
  url: https://github.com/$GITHUB_USER/$GITHUB_REPO
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./clusters/management
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
```

-----

## Deploy Your First Application

### Step 1: Create Application Structure

```bash
# Clone your repository locally
git clone https://github.com/$GITHUB_USER/$GITHUB_REPO.git
cd $GITHUB_REPO

# Create directory structure
mkdir -p applications/podinfo
```

### Step 2: Create Application Manifests

Create `applications/podinfo/namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: podinfo
```

Create `applications/podinfo/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
  namespace: podinfo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: podinfo
  template:
    metadata:
      labels:
        app: podinfo
    spec:
      containers:
      - name: podinfo
        image: ghcr.io/stefanprodan/podinfo:6.5.0
        ports:
        - containerPort: 9898
          name: http
        resources:
          limits:
            memory: "128Mi"
            cpu: "500m"
          requests:
            memory: "64Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /healthz
            port: 9898
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /readyz
            port: 9898
          initialDelaySeconds: 5
          periodSeconds: 10
```

Create `applications/podinfo/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: podinfo
  namespace: podinfo
spec:
  type: ClusterIP
  selector:
    app: podinfo
  ports:
  - port: 9898
    targetPort: http
    name: http
```

Create `applications/podinfo/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml

commonLabels:
  app.kubernetes.io/name: podinfo
  app.kubernetes.io/managed-by: flux
```

### Step 3: Create Flux Kustomization

Create `clusters/management/apps.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 5m0s
  path: ./applications/podinfo
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: podinfo
      namespace: podinfo
  timeout: 2m0s
```

### Step 4: Commit and Push

```bash
# Add all files
git add .

# Commit
git commit -m "feat: add podinfo application"

# Push
git push origin main
```

### Step 5: Watch Flux Deploy

```bash
# Watch Flux reconcile
flux get kustomizations --watch

# Watch pods come up
kubectl get pods -n podinfo --watch

# Check application
flux get all -n flux-system
```

### Step 6: Test the Application

```bash
# Port forward to access the app
kubectl port-forward -n podinfo svc/podinfo 9898:9898

# In another terminal, test
curl http://localhost:9898

# Or open in browser
open http://localhost:9898
```

-----

## GitOps Workflow

### Making Changes

```bash
# Edit deployment
vim applications/podinfo/deployment.yaml

# Change replicas from 2 to 3
spec:
  replicas: 3

# Commit and push
git add applications/podinfo/deployment.yaml
git commit -m "scale: increase podinfo replicas to 3"
git push

# Watch Flux apply the change
flux reconcile kustomization apps --with-source
kubectl get pods -n podinfo --watch
```

### Forcing Reconciliation

```bash
# Force reconcile source
flux reconcile source git flux-system

# Force reconcile kustomization
flux reconcile kustomization flux-system
flux reconcile kustomization apps
```

### Suspending Reconciliation

```bash
# Suspend kustomization
flux suspend kustomization apps

# Make manual changes
kubectl scale deployment podinfo -n podinfo --replicas=5

# Resume reconciliation (Flux will revert to Git state)
flux resume kustomization apps
```

-----

## Flux Advanced Features

### Helm Releases

Create `clusters/management/helm-repos.yaml`:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 1h0m0s
  url: https://stefanprodan.github.io/podinfo
```

Create `applications/podinfo-helm/helmrelease.yaml`:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: podinfo
  namespace: podinfo
spec:
  interval: 5m0s
  chart:
    spec:
      chart: podinfo
      version: '6.5.0'
      sourceRef:
        kind: HelmRepository
        name: podinfo
        namespace: flux-system
  values:
    replicaCount: 2
    resources:
      limits:
        memory: 128Mi
        cpu: 500m
```

### Notifications

Create `clusters/management/notifications.yaml`:

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta2
kind: Provider
metadata:
  name: slack
  namespace: flux-system
spec:
  type: slack
  channel: flux-notifications
  secretRef:
    name: slack-url
---
apiVersion: notification.toolkit.fluxcd.io/v1beta2
kind: Alert
metadata:
  name: flux-system
  namespace: flux-system
spec:
  providerRef:
    name: slack
  eventSeverity: info
  eventSources:
    - kind: GitRepository
      name: '*'
    - kind: Kustomization
      name: '*'
```

### Kustomize Overlays

Structure for multiple environments:

```
applications/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── development/
    │   ├── kustomization.yaml
    │   └── patches.yaml
    ├── staging/
    │   ├── kustomization.yaml
    │   └── patches.yaml
    └── production/
        ├── kustomization.yaml
        └── patches.yaml
```

-----

## Monitoring Flux

### Check Status

```bash
# Overall health
flux check

# All resources
flux get all

# Specific resource types
flux get sources git
flux get kustomizations
flux get helmreleases
```

### View Logs

```bash
# Source controller
kubectl logs -n flux-system deployment/source-controller

# Kustomize controller
kubectl logs -n flux-system deployment/kustomize-controller

# Follow logs
kubectl logs -n flux-system deployment/kustomize-controller -f
```

### View Events

```bash
# Flux events
flux events

# Events for specific resource
flux events --for=Kustomization/apps

# Kubernetes events
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

-----

## Troubleshooting

### Issue: Bootstrap Fails

```bash
# Check prerequisites
flux check --pre

# Verify GitHub token
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Try again with verbose output
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --personal \
  --verbose
```

### Issue: Reconciliation Failing

```bash
# Check kustomization status
flux get kustomizations

# Describe the resource
kubectl describe kustomization apps -n flux-system

# Check logs
kubectl logs -n flux-system deployment/kustomize-controller --tail=50

# Force reconciliation
flux reconcile kustomization apps --with-source
```

### Issue: Git Authentication Errors

```bash
# Check secret
kubectl get secret flux-system -n flux-system

# Regenerate deploy key
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --personal \
  --force
```

### Issue: Resource Not Syncing

```bash
# Verify Git repository is accessible
flux get sources git

# Check if file exists in correct path
git ls-files

# Validate YAML
kubectl apply --dry-run=client -f applications/podinfo/

# Check for typos in paths
flux tree kustomization flux-system
```

-----

## Best Practices

### 1. Directory Structure

```
clusters/
├── management/           # Management cluster configs
│   ├── flux-system/     # Flux system (auto-generated)
│   ├── infrastructure/  # Infrastructure components
│   └── apps/            # Applications
└── production/          # Production cluster configs
```

### 2. Use Dependencies

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
spec:
  dependsOn:
    - name: infrastructure
  # ...
```

### 3. Health Checks

```yaml
spec:
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: podinfo
      namespace: podinfo
```

### 4. Prune Resources

```yaml
spec:
  prune: true  # Remove resources deleted from Git
```

### 5. Set Timeouts

```yaml
spec:
  timeout: 5m0s
  interval: 10m0s
```

-----

## Next Steps

With Flux installed and working, proceed to:

👉 **[04 - Install Crossplane](./04-install-crossplane.md)**

This will cover:

- Installing Crossplane via Flux
- Understanding Crossplane architecture
- Preparing for infrastructure provisioning

## Additional Resources

- [Flux Documentation](https://fluxcd.io/docs/)
- [Flux Best Practices](https://fluxcd.io/docs/guides/best-practices/)
- [GitOps Principles](https://opengitops.dev/)
- [Flux Slack Community](https://fluxcd.io/slack/)

-----

*Estimated time: 30-45 minutes*
