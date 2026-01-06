# Infrastructure Layer

This directory serves as the entry point for all infrastructure components managed by Flux in the management cluster.

## Purpose

The infrastructure layer contains references to core platform services that must be deployed before applications. This includes:

- **Crossplane**: Infrastructure provisioning and management
- **Monitoring**: Prometheus, Grafana (future)
- **Ingress**: NGINX Ingress Controller (future)
- **Certificate Management**: cert-manager (future)
- **Service Mesh**: Istio/Linkerd (future)
- **Secrets Management**: External Secrets Operator (future)

## Architecture

```
clusters/management/
├── flux-system/              # Flux CD (auto-generated)
├── infrastructure/           # This directory - Infrastructure layer
│   └── kustomization.yaml   # References all infrastructure components
├── crossplane-system/        # Crossplane installation
├── monitoring/              # Monitoring stack (future)
├── ingress-nginx/           # Ingress controller (future)
└── apps/                    # Application layer (future)
```

## How It Works

This directory uses a **Kustomization** that references other directories:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../crossplane-system      # Points to crossplane-system directory
  - ../monitoring            # Points to monitoring directory
  # etc.
```

### Why This Pattern?

**Benefits:**

- ✅ **Clear separation of concerns**: Infrastructure vs. applications
- ✅ **Ordered deployment**: Infrastructure first, then apps
- ✅ **Easy to navigate**: Clear directory structure
- ✅ **Reusable components**: Each component is self-contained
- ✅ **Flexible**: Add/remove components easily

**Alternative approaches:**

- ❌ Flat structure: Everything in one directory (hard to maintain)
- ❌ Deep nesting: Too many subdirectories (hard to navigate)

## Current Infrastructure Components

### 1. Crossplane System

**Location**: `../crossplane-system/`

**Purpose**: Provision and manage Azure infrastructure

**Contents**:

- Crossplane core installation
- Azure providers
- ProviderConfig for authentication

**Status**: ✅ Ready to deploy

See <../crossplane-system/README.md> for details.

## Adding New Infrastructure Components

### Step 1: Create Component Directory

```bash
# Example: Adding monitoring stack
mkdir -p clusters/management/monitoring
```

### Step 2: Add Component Manifests

```bash
# Create component files
cat > clusters/management/monitoring/namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
EOF

cat > clusters/management/monitoring/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - prometheus.yaml
  - grafana.yaml
EOF
```

### Step 3: Reference in Infrastructure Kustomization

Edit `clusters/management/infrastructure/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../crossplane-system
  - ../monitoring          # Add new component
```

### Step 4: Commit and Push

```bash
git add clusters/management/monitoring/
git add clusters/management/infrastructure/kustomization.yaml
git commit -m "feat: add monitoring stack"
git push origin main
```

Flux will automatically detect and deploy the new component!

## Deployment Order

Infrastructure components can have dependencies. Use `dependsOn` in Flux Kustomization to control order:

Create `clusters/management/infrastructure-dependencies.yaml`:

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: crossplane-system
  namespace: flux-system
spec:
  interval: 10m
  path: ./clusters/management/crossplane-system
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system

---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: monitoring
  namespace: flux-system
spec:
  interval: 10m
  path: ./clusters/management/monitoring
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  dependsOn:
    - name: crossplane-system  # Wait for Crossplane first

---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: ingress-nginx
  namespace: flux-system
spec:
  interval: 10m
  path: ./clusters/management/ingress-nginx
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  dependsOn:
    - name: cert-manager       # Wait for cert-manager first
```

## Verification

### Check Infrastructure Deployment

```bash
# List all Flux kustomizations
flux get kustomizations

# Check infrastructure specifically
kubectl get kustomizations -n flux-system

# Watch infrastructure deployment
flux get kustomizations --watch
```

### Check Individual Components

```bash
# Crossplane
kubectl get pods -n crossplane-system

# Monitoring (future)
kubectl get pods -n monitoring

# All infrastructure namespaces
kubectl get namespaces | grep -E 'crossplane|monitoring|ingress'
```

## Example Infrastructure Components

### Example 1: Monitoring Stack

```bash
mkdir -p clusters/management/monitoring
```

Create `clusters/management/monitoring/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - helmrepo.yaml
  - prometheus-helmrelease.yaml
  - grafana-helmrelease.yaml
```

### Example 2: Ingress NGINX

```bash
mkdir -p clusters/management/ingress-nginx
```

Create `clusters/management/ingress-nginx/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - helmrepo.yaml
  - helmrelease.yaml
```

### Example 3: cert-manager

```bash
mkdir -p clusters/management/cert-manager
```

Create `clusters/management/cert-manager/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - helmrepo.yaml
  - helmrelease.yaml
  - clusterissuer.yaml
```

## Best Practices

### 1. One Component Per Directory

```
✅ Good:
clusters/management/
├── crossplane-system/
├── monitoring/
└── ingress-nginx/

❌ Bad:
clusters/management/
└── infrastructure/
    ├── crossplane.yaml
    ├── monitoring.yaml
    └── ingress.yaml
```

### 2. Use Meaningful Names

```
✅ Good: crossplane-system, monitoring, ingress-nginx
❌ Bad: infra1, component-a, stuff
```

### 3. Include README in Each Component

Every component directory should have a README.md explaining:

- What the component does
- How to configure it
- How to verify it’s working
- Common troubleshooting steps

### 4. Use Helm for Complex Components

For complex infrastructure like monitoring stacks:

```yaml
# Use HelmRelease instead of raw manifests
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: prometheus
  namespace: monitoring
spec:
  chart:
    spec:
      chart: kube-prometheus-stack
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
```

### 5. Set Appropriate Intervals

```yaml
spec:
  interval: 10m   # Standard for infrastructure
  interval: 1h    # For rarely-changing components
  interval: 5m    # For frequently-updated components
```

### 6. Enable Health Checks

```yaml
spec:
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: prometheus-server
      namespace: monitoring
```

### 7. Use Namespaces

Always create dedicated namespaces for components:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    toolkit.fluxcd.io/tenant: infrastructure
```

## Troubleshooting

### Component Not Deploying

```bash
# Check kustomization status
flux get kustomizations

# Describe for errors
kubectl describe kustomization -n flux-system <component-name>

# Check component directory
kubectl kustomize clusters/management/<component>/

# Force reconcile
flux reconcile kustomization <component-name>
```

### Dependency Issues

```bash
# Check dependency status
kubectl get kustomizations -n flux-system

# Verify dependency is healthy
flux get kustomizations

# Check events
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

### Resource Conflicts

```bash
# Check for conflicting resources
kubectl get all -A | grep <component-name>

# Check kustomization overlays
kubectl kustomize clusters/management/<component>/
```

## Monitoring Infrastructure

### Check All Infrastructure Status

```bash
#!/bin/bash
# infrastructure-status.sh

echo "=== Infrastructure Components Status ==="
echo ""

components=(
  "crossplane-system"
  "monitoring"
  "ingress-nginx"
  "cert-manager"
)

for component in "${components[@]}"; do
  echo "📦 $component:"
  
  # Check if kustomization exists
  if kubectl get kustomization -n flux-system "$component" &>/dev/null; then
    status=$(kubectl get kustomization -n flux-system "$component" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    message=$(kubectl get kustomization -n flux-system "$component" -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}')
    
    if [ "$status" == "True" ]; then
      echo "  ✅ Status: Ready"
    else
      echo "  ❌ Status: Not Ready"
      echo "  Message: $message"
    fi
  else
    echo "  ⏳ Not deployed yet"
  fi
  
  echo ""
done
```

### Set Up Alerts

Configure Flux notifications for infrastructure failures:

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta1
kind: Alert
metadata:
  name: infrastructure-alerts
  namespace: flux-system
spec:
  providerRef:
    name: slack
  eventSeverity: error
  eventSources:
    - kind: Kustomization
      name: '*'
      namespace: flux-system
```

## Migration Guide

### From Manual kubectl apply

If you’re currently deploying infrastructure manually:

**Before** (Manual):

```bash
kubectl apply -f prometheus.yaml
kubectl apply -f grafana.yaml
```

**After** (GitOps):

1. Add manifests to `clusters/management/monitoring/`
1. Create kustomization.yaml
1. Reference in infrastructure/kustomization.yaml
1. Commit and push
1. Flux deploys automatically

### From Helm CLI

**Before** (Helm CLI):

```bash
helm install prometheus prometheus-community/kube-prometheus-stack
```

**After** (GitOps):

1. Create HelmRepository manifest
1. Create HelmRelease manifest
1. Add to infrastructure/kustomization.yaml
1. Commit and push
1. Flux deploys automatically

## Security Considerations

### 1. Namespace Isolation

Use NetworkPolicies to isolate infrastructure components:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: crossplane-system
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### 2. RBAC

Implement proper RBAC for infrastructure namespaces:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: admin-access
  namespace: monitoring
subjects:
  - kind: User
    name: platform-team
roleRef:
  kind: ClusterRole
  name: admin
```

### 3. Secrets Management

Never commit secrets to Git. Use:

- Sealed Secrets
- External Secrets Operator
- SOPS encryption

## Cost Optimization

### Resource Limits

Set appropriate limits for infrastructure components:

```yaml
resources:
  limits:
    cpu: 500m
    memory: 1Gi
  requests:
    cpu: 100m
    memory: 256Mi
```

### Autoscaling

Enable HPA for components that can scale:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: prometheus-server
  namespace: monitoring
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: prometheus-server
  minReplicas: 1
  maxReplicas: 3
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
```

## Next Steps

1. ✅ Deploy Crossplane (already configured)
1. ⏳ Add monitoring stack
1. ⏳ Add ingress controller
1. ⏳ Add cert-manager
1. ⏳ Add secrets management
1. ⏳ Configure backups

See individual component READMEs for detailed guides.

-----

*Infrastructure layer for learning-flux-aks-crossplane repository*
