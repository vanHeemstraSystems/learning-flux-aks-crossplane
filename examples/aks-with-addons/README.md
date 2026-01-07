# AKS with Add-ons Example

This example demonstrates provisioning an Azure Kubernetes Service (AKS) cluster with enterprise-grade add-ons and features using Crossplane and Flux CD.

## 🎯 What This Example Includes

### Azure Resources

- **Resource Group** - Container for all resources
- **Virtual Network** - Network with three subnets
- **Log Analytics Workspace** - For Azure Monitor Container Insights
- **AKS Cluster** - With multiple add-ons enabled

### Enabled AKS Add-ons

- ✅ **Azure Monitor Container Insights** - Container monitoring and logging
- ✅ **Azure Policy** - Policy enforcement for cluster compliance
- ✅ **Workload Identity** - Azure AD integration for pods
- ✅ **Azure Key Vault Provider** - Secrets management
- ✅ **Web Application Routing** - Managed NGINX ingress
- ✅ **Network Policy** - Calico for network security

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Resource Group: rg-aks-addons-001                          │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Virtual Network: vnet-aks-addons (10.1.0.0/16)        │ │
│  │                                                         │ │
│  │  ┌─────────────────┐  ┌─────────────────┐            │ │
│  │  │ Subnet: default │  │ Subnet: aks     │            │ │
│  │  │ 10.1.0.0/24     │  │ 10.1.1.0/24     │            │ │
│  │  └─────────────────┘  └─────────────────┘            │ │
│  │                                                         │ │
│  │  ┌─────────────────────────────────────┐              │ │
│  │  │ Subnet: azure-services              │              │ │
│  │  │ 10.1.2.0/24 (Key Vault, etc.)      │              │ │
│  │  └─────────────────────────────────────┘              │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Log Analytics Workspace                                 │ │
│  │ Name: law-aks-addons-001                               │ │
│  │ Retention: 30 days                                     │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ AKS Cluster: aks-addons-001                            │ │
│  │                                                         │ │
│  │  Node Pool: system                                     │ │
│  │  ├─ 3 nodes (auto-scale: 3-5)                         │ │
│  │  ├─ Standard_D4s_v3                                    │ │
│  │  └─ System workloads only                              │ │
│  │                                                         │ │
│  │  Add-ons Enabled:                                      │ │
│  │  ├─ 📊 Azure Monitor (Container Insights)             │ │
│  │  ├─ 🔒 Azure Policy                                    │ │
│  │  ├─ 🔐 Key Vault Provider                             │ │
│  │  ├─ 🌐 Web Application Routing                        │ │
│  │  └─ 🔑 Workload Identity                              │ │
│  │                                                         │ │
│  │  Network: Azure CNI + Calico                           │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Deployment

### Prerequisites

1. **Crossplane installed** with Azure provider configured
1. **Flux CD installed** in your management cluster
1. **Azure credentials** configured in Crossplane ProviderConfig
1. **Sufficient Azure permissions** to create:
- Resource Groups
- Virtual Networks
- Log Analytics Workspaces
- AKS Clusters

### Method 1: Deploy with Flux CD (Recommended)

1. **Fork or clone** this repository
1. **Create Flux GitRepository source**:

```bash
flux create source git learning-flux-aks \
  --url=https://github.com/YOUR-USERNAME/learning-flux-aks-crossplane \
  --branch=main \
  --interval=1m
```

1. **Create Flux Kustomization**:

```bash
flux create kustomization aks-with-addons \
  --source=GitRepository/learning-flux-aks \
  --path="./examples/aks-with-addons" \
  --prune=true \
  --interval=5m
```

1. **Monitor deployment**:

```bash
# Watch Flux reconciliation
flux get kustomizations --watch

# Check Crossplane resources
kubectl get managed -l example=aks-with-addons

# Watch AKS cluster creation
kubectl get cluster.containerservice.azure.upbound.io -w
```

### Method 2: Deploy with kubectl

```bash
# Apply all resources
kubectl apply -k examples/aks-with-addons/

# Monitor deployment
kubectl get managed -l example=aks-with-addons -w
```

## ⏱️ Deployment Timeline

|Phase                |Duration     |Description                     |
|---------------------|-------------|--------------------------------|
|Resource Group       |1-2 min      |Creates Azure Resource Group    |
|Virtual Network      |2-3 min      |Creates VNet and subnets        |
|Log Analytics        |3-5 min      |Creates workspace for monitoring|
|AKS Cluster          |12-18 min    |Creates AKS with all add-ons    |
|Add-ons Configuration|3-5 min      |Enables and configures add-ons  |
|**Total**            |**21-33 min**|Complete deployment time        |

## 🔍 Monitoring and Validation

### Verify Resource Creation

```bash
# Check all Crossplane resources
kubectl get managed -l example=aks-with-addons

# Check resource statuses
kubectl get resourcegroups.azure.upbound.io
kubectl get virtualnetworks.network.azure.upbound.io
kubectl get workspaces.operationalinsights.azure.upbound.io
kubectl get cluster.containerservice.azure.upbound.io

# Get detailed status
kubectl describe cluster.containerservice.azure.upbound.io aks-addons-001
```

### Access AKS Cluster

```bash
# Get kubeconfig from secret
kubectl get secret aks-addons-001-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > ~/.kube/aks-addons-config

# Set context
export KUBECONFIG=~/.kube/aks-addons-config

# Verify cluster access
kubectl get nodes
kubectl get pods -A
```

### Verify Add-ons

```bash
# Check Azure Monitor
kubectl get pods -n kube-system | grep ama-

# Check Azure Policy
kubectl get pods -n kube-system | grep azure-policy

# Check Key Vault Provider
kubectl get pods -n kube-system | grep secrets-store

# Check Web Application Routing
kubectl get pods -n app-routing-system

# Verify Workload Identity
kubectl get sa -A | grep azure-workload-identity
```

### Azure Portal Verification

1. Navigate to the **AKS cluster** in Azure Portal
1. Check **Insights** for Container Insights data
1. Review **Policies** for compliance status
1. Verify **Extensions** shows installed add-ons

## 💰 Cost Estimate

|Resource     |Configuration     |Est. Cost/Month (West Europe)|
|-------------|------------------|-----------------------------|
|AKS Cluster  |Management        |€0 (free)                    |
|VM Nodes     |3x Standard_D4s_v3|~€306                        |
|Load Balancer|Standard          |~€20                         |
|Public IP    |Static            |~€3                          |
|Outbound Data|100GB             |~€7                          |
|Log Analytics|5GB/day           |~€45                         |
|**Total**    |                  |**~€381/month**              |


> **Note**: Costs vary by region and usage. This is an estimate for testing purposes.

## 🛠️ Customization

### Adjust Node Pool Size

Edit `aks-cluster-with-addons.yaml`:

```yaml
defaultNodePool:
  - nodeCount: 3        # Change initial count
    minCount: 3         # Change minimum
    maxCount: 10        # Change maximum
    vmSize: Standard_D4s_v3  # Change VM size
```

### Change Network CIDR

Edit `virtualnetwork.yaml` and `subnet.yaml`:

```yaml
addressSpace:
  - 10.1.0.0/16         # Change VNet CIDR

addressPrefixes:
  - 10.1.1.0/24         # Change subnet CIDR
```

### Modify Log Analytics Retention

Edit `log-analytics-workspace.yaml`:

```yaml
retentionInDays: 90     # Change from 30 to 90 days
```

### Disable Specific Add-ons

Edit `aks-cluster-with-addons.yaml`:

```yaml
addonProfile:
  - azurePolicy:
      - enabled: false   # Disable Azure Policy
    webAppRouting:
      - enabled: false   # Disable Web App Routing
```

## 🧪 Testing Add-on Features

### Test Azure Monitor

```bash
# Deploy test application
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# View logs in Azure Portal > AKS > Insights > Containers
```

### Test Azure Policy

```bash
# Try to create a privileged pod (should be blocked if policy enabled)
kubectl run privileged-test --image=nginx --privileged

# Check policy compliance in Azure Portal > AKS > Policies
```

### Test Workload Identity

```bash
# Create service account with workload identity
kubectl create sa workload-identity-sa

# Annotate with Azure identity
kubectl annotate sa workload-identity-sa \
  azure.workload.identity/client-id=<YOUR_CLIENT_ID>
```

### Test Key Vault Integration

```bash
# Create SecretProviderClass
kubectl apply -f - <<EOF
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kvname
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    keyvaultName: "your-keyvault-name"
    objects: |
      array:
        - |
          objectName: secret1
          objectType: secret
    tenantId: "your-tenant-id"
EOF
```

## 🔧 Troubleshooting

### AKS Cluster Fails to Create

```bash
# Check cluster status
kubectl describe cluster.containerservice.azure.upbound.io aks-addons-001

# Common issues:
# 1. Insufficient Azure permissions
# 2. Subnet too small for node count
# 3. Log Analytics workspace in different region
```

### Add-ons Not Installing

```bash
# Verify add-on configuration
kubectl get cluster.containerservice.azure.upbound.io aks-addons-001 -o yaml | grep -A 20 addonProfile

# Check Azure Portal for add-on errors
# Navigate to AKS > Settings > Extensions + applications
```

### Cannot Access Cluster

```bash
# Verify kubeconfig secret exists
kubectl get secret aks-addons-001-kubeconfig

# Check if writeConnectionSecretToRef is configured
kubectl get cluster.containerservice.azure.upbound.io aks-addons-001 -o yaml | grep -A 5 writeConnectionSecretToRef
```

### Log Analytics Not Receiving Data

```bash
# Check OMS agent pods
kubectl get pods -n kube-system | grep ama-

# Verify workspace configuration
kubectl get workspaces.operationalinsights.azure.upbound.io law-aks-addons-001 -o yaml

# Verify workspace ID in add-on configuration
```

## 🧹 Cleanup

### Delete with Flux

```bash
# Remove Flux Kustomization
flux delete kustomization aks-with-addons

# This will remove all resources
```

### Delete with kubectl

```bash
# Delete all resources
kubectl delete -k examples/aks-with-addons/

# Verify deletion
kubectl get managed -l example=aks-with-addons
```

### Manual Azure Cleanup (if needed)

```bash
# Login to Azure
az login

# Delete resource group (removes all resources)
az group delete --name rg-aks-addons-001 --yes --no-wait
```

## 📚 Next Steps

After successfully deploying this example:

1. **Explore monitoring**: Check Container Insights in Azure Portal
1. **Test policies**: Try deploying non-compliant resources
1. **Configure workload identity**: Set up Azure AD integration for pods
1. **Add custom policies**: Deploy additional Azure Policy definitions
1. **Scale testing**: Test node auto-scaling under load
1. **Multi-environment**: Check out the `multi-cluster` example for dev/staging/prod

## 🔗 Related Documentation

- [Azure Monitor Container Insights](https://learn.microsoft.com/azure/azure-monitor/containers/container-insights-overview)
- [Azure Policy for AKS](https://learn.microsoft.com/azure/governance/policy/concepts/policy-for-kubernetes)
- [AKS Workload Identity](https://learn.microsoft.com/azure/aks/workload-identity-overview)
- [Azure Key Vault Provider for Secrets Store CSI Driver](https://learn.microsoft.com/azure/aks/csi-secrets-store-driver)
- [Web Application Routing](https://learn.microsoft.com/azure/aks/web-app-routing)

## 📝 Notes

- **Add-ons increase costs**: Each add-on may have additional charges
- **Network policies**: Calico is configured but policies must be defined
- **Workload identity**: Requires Azure AD application registration
- **Key Vault access**: Requires managed identity permissions
- **Monitoring data**: Log Analytics charges based on ingestion volume
