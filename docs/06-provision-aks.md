# 06 - Provision AKS with Crossplane

## Overview

This guide demonstrates how to provision a complete Azure Kubernetes Service (AKS) cluster using Crossplane, including all supporting infrastructure like resource groups, virtual networks, and subnets.

## Prerequisites

Before proceeding, ensure:

- ✅ Azure Provider is configured ([05 - Configure Azure Provider](./05-configure-azure-provider.md))
- ✅ You understand Crossplane managed resources
- ✅ Your Git repository is set up for GitOps

Verify provider readiness:

```bash
# Check providers are healthy
kubectl get providers

# Verify ProviderConfig
kubectl get providerconfigs

# Test with a simple resource
kubectl get resourcegroups --all-namespaces
```

## Architecture

This guide creates the following infrastructure:

```
Azure Subscription
    │
    ├── Resource Group (rg-crossplane-aks-001)
    │   │
    │   ├── Virtual Network (vnet-aks)
    │   │   ├── CIDR: 10.0.0.0/16
    │   │   │
    │   │   ├── Subnet: default
    │   │   │   └── CIDR: 10.0.0.0/24
    │   │   │
    │   │   └── Subnet: aks-subnet
    │   │       └── CIDR: 10.0.1.0/24
    │   │
    │   └── AKS Cluster (aks-crossplane-001)
    │       ├── Kubernetes Version: 1.28.3
    │       ├── Node Pool: system
    │       │   ├── Count: 3
    │       │   ├── VM Size: Standard_D2s_v3
    │       │   └── Auto-scaling: Enabled (1-5)
    │       └── Network: Azure CNI
```

## Method 1: Using Managed Resources (Learning)

This method creates individual Azure resources directly. Great for learning and understanding Crossplane.

### Step 1: Create Resource Group

Create `examples/crossplane-aks/resourcegroup.yaml`:

```yaml
apiVersion: azure.upbound.io/v1beta1
kind: ResourceGroup
metadata:
  name: rg-crossplane-aks-001
  labels:
    environment: development
    managed-by: crossplane
spec:
  forProvider:
    location: West Europe
  providerConfigRef:
    name: default
```

### Step 2: Create Virtual Network

Create `examples/crossplane-aks/virtualnetwork.yaml`:

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: VirtualNetwork
metadata:
  name: vnet-aks
  labels:
    environment: development
spec:
  forProvider:
    addressSpace:
      - 10.0.0.0/16
    location: West Europe
    resourceGroupNameSelector:
      matchLabels:
        environment: development
  providerConfigRef:
    name: default
```

### Step 3: Create Subnets

Create `examples/crossplane-aks/subnets.yaml`:

```yaml
---
apiVersion: network.azure.upbound.io/v1beta1
kind: Subnet
metadata:
  name: subnet-default
  labels:
    environment: development
spec:
  forProvider:
    addressPrefixes:
      - 10.0.0.0/24
    resourceGroupNameSelector:
      matchLabels:
        environment: development
    virtualNetworkNameSelector:
      matchLabels:
        environment: development
  providerConfigRef:
    name: default
---
apiVersion: network.azure.upbound.io/v1beta1
kind: Subnet
metadata:
  name: subnet-aks
  labels:
    environment: development
    purpose: aks
spec:
  forProvider:
    addressPrefixes:
      - 10.0.1.0/24
    resourceGroupNameSelector:
      matchLabels:
        environment: development
    virtualNetworkNameSelector:
      matchLabels:
        environment: development
  providerConfigRef:
    name: default
```

### Step 4: Create AKS Cluster

Create `examples/crossplane-aks/aks-cluster.yaml`:

```yaml
apiVersion: containerservice.azure.upbound.io/v1beta1
kind: KubernetesCluster
metadata:
  name: aks-crossplane-001
  labels:
    environment: development
spec:
  forProvider:
    location: West Europe
    resourceGroupNameSelector:
      matchLabels:
        environment: development
    
    dnsPrefix: aks-crossplane-001
    kubernetesVersion: "1.28.3"
    
    # Default node pool
    defaultNodePool:
      - name: system
        nodeCount: 3
        vmSize: Standard_D2s_v3
        enableAutoScaling: true
        minCount: 1
        maxCount: 5
        vnetSubnetIdSelector:
          matchLabels:
            environment: development
            purpose: aks
    
    # Identity
    identity:
      - type: SystemAssigned
    
    # Network profile
    networkProfile:
      - networkPlugin: azure
        networkPolicy: calico
        dnsServiceIp: 10.2.0.10
        serviceCidr: 10.2.0.0/24
    
    # Add-ons
    addonProfile:
      - httpApplicationRouting:
          - enabled: false
        omsAgent:
          - enabled: false
  
  providerConfigRef:
    name: default
  
  # Write connection details to secret
  writeConnectionSecretToRef:
    name: aks-crossplane-001-kubeconfig
    namespace: default
```

### Step 5: Create Kustomization

Create `examples/crossplane-aks/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - resourcegroup.yaml
  - virtualnetwork.yaml
  - subnets.yaml
  - aks-cluster.yaml

# Set common labels
commonLabels:
  app.kubernetes.io/managed-by: crossplane
  project: learning-crossplane
```

### Step 6: Deploy with Flux

Create `clusters/management/workload-clusters.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: workload-clusters
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./examples/crossplane-aks
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: true
  timeout: 30m0s
  healthChecks:
    - apiVersion: containerservice.azure.upbound.io/v1beta1
      kind: KubernetesCluster
      name: aks-crossplane-001
      namespace: default
```

### Step 7: Commit and Deploy

```bash
# Add files
git add examples/crossplane-aks/
git add clusters/management/workload-clusters.yaml

# Commit
git commit -m "feat: provision AKS cluster via Crossplane"

# Push
git push

# Watch deployment
flux get kustomizations --watch
```

### Step 8: Monitor Provisioning

AKS cluster provisioning takes 10-15 minutes:

```bash
# Watch all resources
kubectl get managed --watch

# Check specific resource
kubectl describe kubernetescluster aks-crossplane-001

# View events
kubectl get events --sort-by='.lastTimestamp' | grep aks-crossplane-001
```

### Step 9: Access the Cluster

Once the cluster is ready:

```bash
# Get the kubeconfig secret
kubectl get secret aks-crossplane-001-kubeconfig -n default -o jsonpath='{.data.kubeconfig}' | base64 -d > aks-crossplane-001-kubeconfig.yaml

# Use the kubeconfig
export KUBECONFIG=aks-crossplane-001-kubeconfig.yaml

# Verify access
kubectl get nodes

# Test deployment
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer
kubectl get svc nginx --watch
```

## Method 2: Using Compositions (Platform Engineering)

Compositions allow you to create higher-level abstractions. See your previous chat conversation for complete composition examples.

Key benefits:

- Hide complexity from developers
- Enforce organizational standards
- Reusable infrastructure patterns
- Self-service capabilities

## Verification Checklist

After provisioning:

```bash
# ✓ Resource Group exists
az group show --name rg-crossplane-aks-001

# ✓ Virtual Network exists
az network vnet show \
  --resource-group rg-crossplane-aks-001 \
  --name vnet-aks

# ✓ Subnets exist
az network vnet subnet list \
  --resource-group rg-crossplane-aks-001 \
  --vnet-name vnet-aks

# ✓ AKS Cluster is running
az aks show \
  --resource-group rg-crossplane-aks-001 \
  --name aks-crossplane-001

# ✓ Cluster is accessible
kubectl --kubeconfig=aks-crossplane-001-kubeconfig.yaml get nodes
```

## Understanding Resource Dependencies

Crossplane handles dependencies through selectors:

```yaml
# VNet depends on Resource Group
resourceGroupNameSelector:
  matchLabels:
    environment: development

# Subnet depends on VNet
virtualNetworkNameSelector:
  matchLabels:
    environment: development

# AKS depends on Subnet
vnetSubnetIdSelector:
  matchLabels:
    purpose: aks
```

**Key Points**:

- Resources wait for dependencies to be ready
- Use labels for loose coupling
- Crossplane automatically determines order

## Cost Considerations

**Estimated Monthly Costs (West Europe)**:

- AKS Control Plane: Free (single cluster)
- Node Pool (3x Standard_D2s_v3): ~€280/month
- Virtual Network: ~€5/month
- Load Balancer (if used): ~€20/month
- **Total**: ~€305/month

**Cost Optimization**:

```yaml
# Use smaller VMs for dev
vmSize: Standard_B2s  # ~€30/month per node

# Use spot instances (70% discount)
spotMaxPrice: -1
priority: Spot

# Enable auto-scaling
enableAutoScaling: true
minCount: 1
maxCount: 3
```

## Cleanup

To delete all resources:

```bash
# Delete the Flux kustomization (cascades to all resources)
flux delete kustomization workload-clusters

# Or delete individual resources
kubectl delete kubernetescluster aks-crossplane-001
kubectl delete subnet subnet-aks subnet-default
kubectl delete virtualnetwork vnet-aks
kubectl delete resourcegroup rg-crossplane-aks-001

# Verify in Azure
az group show --name rg-crossplane-aks-001
# Should show "not found"
```

## Troubleshooting

### Issue: Resource Stuck in “Creating”

```bash
# Check resource status
kubectl describe kubernetescluster aks-crossplane-001

# Look for errors in status.conditions
kubectl get kubernetescluster aks-crossplane-001 -o yaml

# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-containerservice
```

### Issue: Authentication Errors

```bash
# Verify ProviderConfig
kubectl get providerconfig default -o yaml

# Test service principal
az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID

# Check role assignments
az role assignment list --assignee $AZURE_CLIENT_ID
```

### Issue: Network Configuration Errors

```bash
# Check subnet ID
kubectl get subnet subnet-aks -o yaml

# Verify CIDR ranges don't overlap
# AKS service CIDR: 10.2.0.0/24
# Subnet CIDR: 10.0.1.0/24
# DNS service IP: 10.2.0.10 (must be in service CIDR)
```

### Issue: Cluster Not Accessible

```bash
# Verify kubeconfig secret exists
kubectl get secret aks-crossplane-001-kubeconfig -n default

# Extract and test kubeconfig
kubectl get secret aks-crossplane-001-kubeconfig -n default \
  -o jsonpath='{.data.kubeconfig}' | base64 -d > test-kubeconfig.yaml

kubectl --kubeconfig=test-kubeconfig.yaml get nodes
```

## Best Practices

### 1. Use Labels for Organization

```yaml
metadata:
  labels:
    environment: production
    team: platform
    cost-center: engineering
    managed-by: crossplane
```

### 2. Enable Monitoring and Logging

```yaml
addonProfile:
  - omsAgent:
      - enabled: true
        logAnalyticsWorkspaceResourceId: /subscriptions/.../workspaces/...
```

### 3. Configure Auto-scaling

```yaml
defaultNodePool:
  - enableAutoScaling: true
    minCount: 2
    maxCount: 10
```

### 4. Use System-Assigned Managed Identity

```yaml
identity:
  - type: SystemAssigned
```

### 5. Implement Network Policies

```yaml
networkProfile:
  - networkPlugin: azure
    networkPolicy: calico  # or azure
```

## Next Steps

Now that you can provision AKS clusters, explore advanced scenarios:

👉 **[07 - Advanced Scenarios](./07-advanced-scenarios.md)**

This will cover:

- Creating compositions
- Multi-cluster patterns
- Advanced networking
- Security configurations

## Additional Resources

- [AKS Best Practices](https://learn.microsoft.com/en-us/azure/aks/best-practices)
- [Crossplane Azure Examples](https://github.com/upbound/provider-azure/tree/main/examples)
- [AKS Network Concepts](https://learn.microsoft.com/en-us/azure/aks/concepts-network)
- [Crossplane Composition Guide](https://docs.crossplane.io/latest/concepts/compositions/)

-----

*Estimated time: 45-60 minutes (including 10-15 min cluster provisioning)*
