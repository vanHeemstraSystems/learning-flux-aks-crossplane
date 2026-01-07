# Simple AKS Example

This example demonstrates how to provision a basic AKS cluster using Crossplane managed resources. This is the most straightforward approach for learning Crossplane.

## What This Example Creates

```
Azure Subscription
    │
    └── Resource Group (rg-simple-aks)
        │
        ├── Virtual Network (vnet-simple-aks)
        │   ├── Address Space: 10.0.0.0/16
        │   │
        │   ├── Subnet: default (10.0.0.0/24)
        │   └── Subnet: aks-subnet (10.0.1.0/24)
        │
        └── AKS Cluster (aks-simple-001)
            ├── Kubernetes Version: 1.28.3
            ├── Node Count: 3
            ├── VM Size: Standard_D2s_v3
            ├── Network Plugin: Azure CNI
            ├── Network Policy: Calico
            └── Identity: System-assigned Managed Identity
```

## Prerequisites

- ✅ Crossplane installed on management cluster
- ✅ Azure Provider configured
- ✅ ProviderConfig with valid credentials
- ✅ Flux CD installed and syncing

## Files in This Example

|File                 |Purpose                                      |
|---------------------|---------------------------------------------|
|`resourcegroup.yaml` |Azure Resource Group                         |
|`virtualnetwork.yaml`|Virtual Network with address space           |
|`subnet.yaml`        |Two subnets (default and aks-subnet)         |
|`aks-cluster.yaml`   |AKS cluster with default node pool           |
|`kustomization.yaml` |Kustomize configuration tying it all together|

## Deployment Methods

### Method 1: Using Flux (Recommended)

1. **Copy this example to your infrastructure**:

```bash
cp -r examples/simple-aks infrastructure/simple-aks-001
```

1. **Customize the resources** (optional):

```bash
# Edit resource names, locations, sizes, etc.
vim infrastructure/simple-aks-001/*.yaml
```

1. **Create Flux Kustomization**:

Create `clusters/management/simple-aks.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: simple-aks
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./infrastructure/simple-aks-001
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  healthChecks:
    - apiVersion: containerservice.azure.upbound.io/v1beta1
      kind: KubernetesCluster
      name: aks-simple-001
      namespace: default
  timeout: 30m0s
```

1. **Commit and push**:

```bash
git add infrastructure/simple-aks-001
git add clusters/management/simple-aks.yaml
git commit -m "feat: deploy simple AKS cluster"
git push
```

1. **Watch deployment**:

```bash
# Watch Flux
flux get kustomizations --watch

# Watch Crossplane resources
kubectl get managed --watch

# Check specific resources
kubectl get resourcegroup
kubectl get virtualnetwork
kubectl get subnet
kubectl get kubernetescluster
```

### Method 2: Direct kubectl Apply

For testing or learning:

```bash
# Apply directly
kubectl apply -k examples/simple-aks/

# Watch resources
kubectl get managed --watch
```

## Timeline

|Phase          |Duration         |What’s Happening                    |
|---------------|-----------------|------------------------------------|
|Resource Group |30 seconds       |Creating resource group in Azure    |
|Virtual Network|1-2 minutes      |Creating VNet and validating CIDR   |
|Subnets        |1-2 minutes      |Creating subnets within VNet        |
|AKS Cluster    |10-15 minutes    |Provisioning control plane and nodes|
|**Total**      |**15-20 minutes**|End-to-end deployment               |

## Monitoring Progress

### Check Crossplane Resources

```bash
# Overview of all resources
kubectl get managed

# Detailed status
kubectl describe resourcegroup rg-simple-aks
kubectl describe virtualnetwork vnet-simple-aks
kubectl describe subnet subnet-default
kubectl describe subnet subnet-aks
kubectl describe kubernetescluster aks-simple-001
```

### Check in Azure Portal

```bash
# Or use Azure CLI
az group show --name rg-simple-aks
az network vnet show --resource-group rg-simple-aks --name vnet-simple-aks
az aks show --resource-group rg-simple-aks --name aks-simple-001
```

### Check Crossplane Logs

```bash
# Provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-network --tail=50
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-containerservice --tail=50
```

## Accessing the Cluster

Once the cluster is ready (READY=True, SYNCED=True):

```bash
# Get kubeconfig from secret
kubectl get secret aks-simple-001-kubeconfig -n default \
  -o jsonpath='{.data.kubeconfig}' | base64 -d > simple-aks-kubeconfig.yaml

# Use the kubeconfig
export KUBECONFIG=simple-aks-kubeconfig.yaml

# Verify access
kubectl get nodes

# Check cluster info
kubectl cluster-info
```

## Testing the Cluster

Deploy a test application:

```bash
# Create test namespace
kubectl create namespace test-app

# Deploy nginx
kubectl create deployment nginx --image=nginx -n test-app

# Expose as LoadBalancer
kubectl expose deployment nginx --port=80 --type=LoadBalancer -n test-app

# Wait for external IP
kubectl get svc -n test-app --watch

# Test access
curl http://<EXTERNAL-IP>
```

## Cost Estimate

**Monthly costs (West Europe region)**:

|Resource                   |Estimated Cost       |
|---------------------------|---------------------|
|AKS Control Plane          |Free (single cluster)|
|3x Standard_D2s_v3 nodes   |~€210/month          |
|Virtual Network            |~€5/month            |
|Load Balancer (if deployed)|~€20/month           |
|**Total**                  |**~€235/month**      |

**Cost optimization tips**:

```yaml
# Use smaller VMs
vmSize: Standard_B2s  # ~€30/month per node

# Enable auto-scaling
enableAutoScaling: true
minCount: 1
maxCount: 3

# Use spot instances
priority: Spot
spotMaxPrice: -1  # Use current spot price
```

## Customization Examples

### Change Region

```yaml
# In all files, change:
location: North Europe  # or any other region
```

### Change Node Size

```yaml
# In aks-cluster.yaml
defaultNodePool:
  - vmSize: Standard_D4s_v3  # or Standard_B2s for dev
```

### Add More Nodes

```yaml
# In aks-cluster.yaml
defaultNodePool:
  - nodeCount: 5  # increase from 3
```

### Change Kubernetes Version

```yaml
# In aks-cluster.yaml
kubernetesVersion: "1.29.0"  # update version
```

## Troubleshooting

### Issue: Resource Group Stuck in Creating

```bash
# Check status
kubectl describe resourcegroup rg-simple-aks

# Check events
kubectl get events --sort-by='.lastTimestamp' | grep rg-simple-aks

# Verify Azure credentials
kubectl get secret azure-credentials -n crossplane-system
```

### Issue: VNet Creation Fails

```bash
# Common causes:
# - CIDR overlap with existing VNet
# - Quota exceeded
# - Invalid CIDR format

# Check Azure quota
az network vnet list --query "[?location=='West Europe'].length(@)"

# Verify CIDR doesn't overlap
az network vnet list --resource-group rg-simple-aks
```

### Issue: AKS Cluster Fails to Provision

```bash
# Check detailed status
kubectl get kubernetescluster aks-simple-001 -o yaml

# Common issues:
# - Subnet not ready
# - VM quota exceeded
# - Network configuration errors

# Check provider logs
kubectl logs -n crossplane-system \
  -l pkg.crossplane.io/provider=provider-azure-containerservice \
  --tail=100
```

### Issue: Cannot Access Cluster

```bash
# Verify kubeconfig secret exists
kubectl get secret aks-simple-001-kubeconfig -n default

# Re-extract kubeconfig
kubectl get secret aks-simple-001-kubeconfig -n default \
  -o jsonpath='{.data.kubeconfig}' | base64 -d > kubeconfig.yaml

# Test with explicit kubeconfig
kubectl --kubeconfig=kubeconfig.yaml get nodes
```

## Cleanup

To delete all resources:

```bash
# Delete Flux kustomization (cascades to all resources)
flux delete kustomization simple-aks

# Or delete resources individually
kubectl delete kubernetescluster aks-simple-001
kubectl delete subnet subnet-aks subnet-default
kubectl delete virtualnetwork vnet-simple-aks
kubectl delete resourcegroup rg-simple-aks

# Verify in Azure (may take 5-10 minutes)
az group show --name rg-simple-aks
# Should return: ResourceGroupNotFound
```

**⚠️ Important**: Always verify deletion in Azure to avoid unexpected costs!

## Next Steps

After successfully deploying this example:

1. **Experiment with modifications**: Change node sizes, counts, regions
1. **Deploy applications**: Use the cluster for real workloads
1. **Try advanced example**: Move to `examples/aks-with-addons/`
1. **Learn compositions**: Create reusable infrastructure patterns
1. **Implement GitOps**: Deploy applications using Flux

## Related Documentation

- [06 - Provision AKS](../../docs/06-provision-aks.md) - Detailed provisioning guide
- [07 - Advanced Scenarios](../../docs/07-advanced-scenarios.md) - Compositions and patterns
- [08 - Troubleshooting](../../docs/08-troubleshooting.md) - Common issues

## Questions?

- Check [Troubleshooting Guide](../../docs/08-troubleshooting.md)
- Review [Crossplane Docs](https://docs.crossplane.io/)
- Ask in [Crossplane Slack](https://slack.crossplane.io/)

-----

*This example is designed for learning. For production, consider using Compositions for reusability and standardization.*
