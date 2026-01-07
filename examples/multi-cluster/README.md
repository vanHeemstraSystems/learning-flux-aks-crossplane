# Multi-Cluster Example

This example demonstrates deploying multiple AKS clusters across different environments (dev, staging, production) using Crossplane and Flux CD with GitOps practices.

## 🎯 What This Example Includes

### Three Environments

- **Development** - Small cluster for development and testing
- **Staging** - Medium cluster mirroring production configuration
- **Production** - Full-scale cluster with high availability

### Per-Environment Resources

- Resource Group (isolated per environment)
- Virtual Network (separate IP ranges)
- Subnets (default + AKS)
- AKS Cluster (sized for environment needs)

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     DEVELOPMENT ENVIRONMENT                      │
│  Resource Group: rg-aks-dev                                     │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ VNet: vnet-aks-dev (10.10.0.0/16)                         │ │
│  │  ├─ Subnet: default (10.10.0.0/24)                        │ │
│  │  └─ Subnet: aks (10.10.1.0/24)                            │ │
│  │                                                             │ │
│  │ AKS: aks-dev-001                                           │ │
│  │  ├─ Nodes: 2 (Standard_D2s_v3)                            │ │
│  │  ├─ Auto-scale: 2-3                                        │ │
│  │  └─ Purpose: Development & Testing                         │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     STAGING ENVIRONMENT                          │
│  Resource Group: rg-aks-staging                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ VNet: vnet-aks-staging (10.20.0.0/16)                     │ │
│  │  ├─ Subnet: default (10.20.0.0/24)                        │ │
│  │  └─ Subnet: aks (10.20.1.0/24)                            │ │
│  │                                                             │ │
│  │ AKS: aks-staging-001                                       │ │
│  │  ├─ Nodes: 3 (Standard_D4s_v3)                            │ │
│  │  ├─ Auto-scale: 3-5                                        │ │
│  │  └─ Purpose: Pre-production Testing                        │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    PRODUCTION ENVIRONMENT                        │
│  Resource Group: rg-aks-production                              │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ VNet: vnet-aks-production (10.30.0.0/16)                  │ │
│  │  ├─ Subnet: default (10.30.0.0/24)                        │ │
│  │  └─ Subnet: aks (10.30.1.0/24)                            │ │
│  │                                                             │ │
│  │ AKS: aks-production-001                                    │ │
│  │  ├─ Nodes: 5 (Standard_D4s_v3)                            │ │
│  │  ├─ Auto-scale: 5-10                                       │ │
│  │  ├─ Availability Zones: 1, 2, 3                           │ │
│  │  └─ Purpose: Production Workloads                          │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🔄 GitOps Workflow

```
Development:
  Code Changes → Dev Cluster (Automatic)
        ↓
      Tests Pass
        ↓
Staging:
  Manual Promotion → Staging Cluster
        ↓
   Validation & QA
        ↓
Production:
  Manual Promotion → Production Cluster (with Approval)
```

## 🚀 Deployment

### Prerequisites

1. **Crossplane installed** with Azure provider configured
1. **Flux CD installed** in your management cluster
1. **Azure credentials** configured in Crossplane ProviderConfig
1. **Sufficient Azure quota** for multiple clusters

### Deploy All Environments

#### Option 1: Deploy All at Once

```bash
# Create Flux GitRepository source
flux create source git learning-flux-aks \
  --url=https://github.com/YOUR-USERNAME/learning-flux-aks-crossplane \
  --branch=main \
  --interval=1m

# Deploy all environments
flux create kustomization multi-cluster-dev \
  --source=GitRepository/learning-flux-aks \
  --path="./examples/multi-cluster/dev" \
  --prune=true \
  --interval=5m

flux create kustomization multi-cluster-staging \
  --source=GitRepository/learning-flux-aks \
  --path="./examples/multi-cluster/staging" \
  --prune=true \
  --interval=5m

flux create kustomization multi-cluster-production \
  --source=GitRepository/learning-flux-aks \
  --path="./examples/multi-cluster/production" \
  --prune=true \
  --interval=5m
```

#### Option 2: Progressive Deployment (Recommended)

```bash
# Step 1: Deploy Dev first
flux create kustomization multi-cluster-dev \
  --source=GitRepository/learning-flux-aks \
  --path="./examples/multi-cluster/dev" \
  --prune=true \
  --interval=5m

# Wait for dev to be ready (~15 minutes)
flux get kustomization multi-cluster-dev --watch

# Step 2: Deploy Staging
flux create kustomization multi-cluster-staging \
  --source=GitRepository/learning-flux-aks \
  --path="./examples/multi-cluster/staging" \
  --prune=true \
  --interval=5m \
  --depends-on=multi-cluster-dev

# Step 3: Deploy Production (with dependency)
flux create kustomization multi-cluster-production \
  --source=GitRepository/learning-flux-aks \
  --path="./examples/multi-cluster/production" \
  --prune=true \
  --interval=5m \
  --depends-on=multi-cluster-staging
```

#### Option 3: Deploy with kubectl

```bash
# Deploy individually
kubectl apply -k examples/multi-cluster/dev/
kubectl apply -k examples/multi-cluster/staging/
kubectl apply -k examples/multi-cluster/production/

# Or deploy all at once
for env in dev staging production; do
  kubectl apply -k examples/multi-cluster/$env/
done
```

### Monitor Deployment

```bash
# Watch all environments
kubectl get managed -l app.kubernetes.io/name=multi-cluster -w

# Check specific environment
kubectl get managed -l environment=dev
kubectl get managed -l environment=staging
kubectl get managed -l environment=production

# Detailed status
kubectl get cluster.containerservice.azure.upbound.io
```

## ⏱️ Deployment Timeline

|Environment|Resources                  |Duration |Total Time|
|-----------|---------------------------|---------|----------|
|Development|RG, VNet, AKS (2 nodes)    |12-15 min|12-15 min |
|Staging    |RG, VNet, AKS (3 nodes)    |15-18 min|27-33 min |
|Production |RG, VNet, AKS (5 nodes, HA)|18-25 min|45-58 min |

**Parallel Deployment**: All three ~25-30 minutes
**Sequential Deployment**: Total ~45-58 minutes

## 🔍 Environment Details

### Development Environment

```yaml
Cluster: aks-dev-001
Nodes: 2 (auto-scale 2-3)
VM Size: Standard_D2s_v3 (2 vCPU, 8 GB RAM)
Network: 10.10.0.0/16
Purpose: Development and feature testing
Cost: ~€160/month
```

**Use Cases**:

- Feature development
- Integration testing
- Experimentation
- Developer workloads

### Staging Environment

```yaml
Cluster: aks-staging-001
Nodes: 3 (auto-scale 3-5)
VM Size: Standard_D4s_v3 (4 vCPU, 16 GB RAM)
Network: 10.20.0.0/16
Purpose: Pre-production validation
Cost: ~€325/month
```

**Use Cases**:

- QA testing
- Performance testing
- Security validation
- Release candidate testing

### Production Environment

```yaml
Cluster: aks-production-001
Nodes: 5 (auto-scale 5-10)
VM Size: Standard_D4s_v3 (4 vCPU, 16 GB RAM)
Network: 10.30.0.0/16
Availability Zones: 1, 2, 3
Purpose: Production workloads
Cost: ~€535/month
```

**Features**:

- High availability across 3 zones
- Larger node pool for capacity
- Production-grade configuration
- Enhanced monitoring

## 💰 Total Cost Estimate (West Europe)

|Environment|Nodes |VM Size        |Est. Cost/Month  |
|-----------|------|---------------|-----------------|
|Development|2     |Standard_D2s_v3|~€160            |
|Staging    |3     |Standard_D4s_v3|~€325            |
|Production |5     |Standard_D4s_v3|~€535            |
|**Total**  |**10**|               |**~€1,020/month**|


> Add ~20% for networking, storage, and egress costs

## 🔐 Access Each Cluster

### Development

```bash
# Get kubeconfig
kubectl get secret aks-dev-001-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > ~/.kube/aks-dev-config

# Use the config
export KUBECONFIG=~/.kube/aks-dev-config
kubectl get nodes
```

### Staging

```bash
# Get kubeconfig
kubectl get secret aks-staging-001-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > ~/.kube/aks-staging-config

# Use the config
export KUBECONFIG=~/.kube/aks-staging-config
kubectl get nodes
```

### Production

```bash
# Get kubeconfig
kubectl get secret aks-production-001-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > ~/.kube/aks-production-config

# Use the config
export KUBECONFIG=~/.kube/aks-production-config
kubectl get nodes
```

### Switch Between Environments

```bash
# Add all contexts
kubectl config use-context aks-dev-001
kubectl config use-context aks-staging-001
kubectl config use-context aks-production-001

# Or use kubectx (if installed)
kubectx aks-dev-001
kubectx aks-staging-001
kubectx aks-production-001
```

## 🔄 Promotion Workflow

### Step 1: Develop in Dev

```bash
# Deploy to dev
kubectl apply -f app-manifests/ --context=aks-dev-001

# Test functionality
kubectl get pods --context=aks-dev-001
```

### Step 2: Promote to Staging

```bash
# Create staging branch/tag
git checkout -b release/v1.0.0
git push origin release/v1.0.0

# Update staging Flux source to track release branch
flux create source git app-staging \
  --url=https://github.com/YOUR-USERNAME/your-app \
  --branch=release/v1.0.0

# Deploy to staging
flux reconcile kustomization app-staging
```

### Step 3: Validate in Staging

```bash
# Run tests in staging
kubectl --context=aks-staging-001 run test-pod --rm -it --image=curlimages/curl -- sh

# Check logs
kubectl logs -l app=your-app --context=aks-staging-001

# Performance testing
# Load testing
```

### Step 4: Promote to Production

```bash
# Create production tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Update production Flux source to track tag
flux create source git app-production \
  --url=https://github.com/YOUR-USERNAME/your-app \
  --tag=v1.0.0

# Deploy to production (requires approval)
flux reconcile kustomization app-production
```

## 🛠️ Customization

### Change Node Count

Edit the respective environment’s `aks-cluster.yaml`:

**Dev**:

```yaml
defaultNodePool:
  - nodeCount: 2
    minCount: 2
    maxCount: 3
```

**Staging**:

```yaml
defaultNodePool:
  - nodeCount: 3
    minCount: 3
    maxCount: 5
```

**Production**:

```yaml
defaultNodePool:
  - nodeCount: 5
    minCount: 5
    maxCount: 10
```

### Change VM Sizes

```yaml
# Dev - smaller VMs
vmSize: Standard_D2s_v3

# Staging - medium VMs
vmSize: Standard_D4s_v3

# Production - larger VMs or same as staging
vmSize: Standard_D4s_v3  # or Standard_D8s_v3
```

### Change Network Ranges

```yaml
# Dev
addressSpace: [10.10.0.0/16]

# Staging
addressSpace: [10.20.0.0/16]

# Production
addressSpace: [10.30.0.0/16]
```

### Add Fourth Environment (QA)

```bash
# Copy staging as template
cp -r examples/multi-cluster/staging examples/multi-cluster/qa

# Update names and labels in all files
sed -i 's/staging/qa/g' examples/multi-cluster/qa/*.yaml
sed -i 's/10.20/10.40/g' examples/multi-cluster/qa/*.yaml
```

## 🧪 Testing Strategy

### Development Testing

- Unit tests
- Integration tests
- Feature validation
- Quick iterations

### Staging Testing

- End-to-end tests
- Performance tests
- Security scans
- Load testing
- Disaster recovery drills

### Production Testing

- Smoke tests post-deployment
- Synthetic monitoring
- Canary deployments
- Blue-green deployments

## 📊 Monitoring Strategy

### Per-Environment Monitoring

```yaml
Development:
  - Basic pod/node metrics
  - Application logs
  - Development-specific alerts (informational)

Staging:
  - Full observability stack
  - Performance metrics
  - Pre-production alerts (warning)

Production:
  - Enterprise monitoring
  - SLA/SLO tracking
  - Critical alerts (page on-call)
  - Audit logging
```

## 🔧 Troubleshooting

### Environment Won’t Deploy

```bash
# Check Crossplane provider
kubectl get providers

# Check resource status
kubectl describe cluster.containerservice.azure.upbound.io aks-<env>-001

# Check Azure quota
az vm list-usage --location "West Europe" -o table
```

### Can’t Access Cluster

```bash
# Verify secret exists
kubectl get secret aks-<env>-001-kubeconfig

# Check secret content
kubectl get secret aks-<env>-001-kubeconfig -o yaml

# Regenerate if needed
kubectl delete secret aks-<env>-001-kubeconfig
# Crossplane will recreate it
```

### Nodes Not Scaling

```bash
# Check cluster autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler

# Verify autoscaler configuration
kubectl get cluster.containerservice.azure.upbound.io aks-<env>-001 -o yaml | grep -A 10 autoScalerProfile
```

### Different Behavior Across Environments

```bash
# Compare configurations
diff <(kubectl get cluster aks-dev-001 -o yaml) \
     <(kubectl get cluster aks-staging-001 -o yaml)

# Check Kubernetes versions match
kubectl version --short --context=aks-dev-001
kubectl version --short --context=aks-staging-001
kubectl version --short --context=aks-production-001
```

## 🧹 Cleanup

### Delete Single Environment

```bash
# Delete via Flux
flux delete kustomization multi-cluster-dev

# Or via kubectl
kubectl delete -k examples/multi-cluster/dev/
```

### Delete All Environments

```bash
# Delete all Flux kustomizations
flux delete kustomization multi-cluster-dev
flux delete kustomization multi-cluster-staging
flux delete kustomization multi-cluster-production

# Or delete all at once
for env in dev staging production; do
  kubectl delete -k examples/multi-cluster/$env/
done
```

### Verify Cleanup

```bash
# Check remaining resources
kubectl get managed -l app.kubernetes.io/name=multi-cluster

# Check Azure
az group list --query "[?starts_with(name,'rg-aks-')].name" -o table
```

## 📚 Best Practices

### Environment Parity

- Keep staging as close to production as possible
- Use same Kubernetes version across environments
- Test promotion process regularly

### Security

- Use separate Azure subscriptions per environment (recommended)
- Implement RBAC per environment
- Use different service principals per environment
- Enable audit logging in all environments

### Cost Management

- Use smaller VMs in dev
- Implement auto-shutdown in dev/staging
- Monitor costs per environment
- Use Azure Cost Management tags

### GitOps

- Use branches for dev/staging
- Use tags for production
- Require PR approvals for production
- Implement automated testing in CI/CD

## 🔗 Related Examples

- **[simple-aks](../simple-aks/)** - Basic single cluster
- **[aks-with-addons](../aks-with-addons/)** - Cluster with monitoring and policies

## 📝 Notes

- **Production uses availability zones** for high availability
- **Each environment is isolated** in its own resource group
- **Network ranges don’t overlap** allowing future peering if needed
- **Progressive scaling**: dev (2 nodes) → staging (3 nodes) → prod (5 nodes)
- **Cost scales with environment criticality**
