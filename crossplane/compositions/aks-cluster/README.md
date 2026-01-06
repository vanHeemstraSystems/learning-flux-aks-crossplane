# AKS Cluster Composition

This composition provides a high-level API for provisioning complete AKS clusters with networking infrastructure.

## What This Creates

When you create an AKS cluster using this composition, Crossplane automatically provisions:

1. **Resource Group** - Container for all resources
1. **Virtual Network** - Network with 10.0.0.0/16 address space
1. **Subnet** - Subnet for AKS nodes (10.0.1.0/24)
1. **AKS Cluster** - Managed Kubernetes cluster with:
- System-assigned managed identity
- Azure CNI networking
- Calico network policies
- Cluster autoscaler
- OIDC issuer (for workload identity)
- Monitoring enabled

## Files

|File                |Purpose               |
|--------------------|----------------------|
|`definition.yaml`   |Defines the API (XRD) |
|`composition.yaml`  |Implements the pattern|
|`example-claim.yaml`|Example usage         |
|`README.md`         |This file             |

## API Overview

### Simple Interface

Users request clusters with simple parameters:

```yaml
apiVersion: platform.example.org/v1alpha1
kind: AKSCluster
metadata:
  name: my-cluster
spec:
  parameters:
    clusterName: my-cluster
    size: medium              # small, medium, or large
    location: West Europe
    kubernetesVersion: "1.28"
    environment: dev
```

### Size Options

|Size  |Nodes|VM Size        |Min|Max|Use Case  |
|------|-----|---------------|---|---|----------|
|small |2    |Standard_D2s_v3|2  |5  |Dev/Test  |
|medium|3    |Standard_D4s_v3|3  |10 |Staging   |
|large |5    |Standard_D8s_v3|3  |20 |Production|

## Installation

### 1. Install XRD and Composition

```bash
# Apply the definition
kubectl apply -f definition.yaml

# Apply the composition
kubectl apply -f composition.yaml

# Verify
kubectl get xrd
kubectl get composition
```

### 2. Create a Cluster Claim

```bash
# Apply example claim
kubectl apply -f example-claim.yaml

# Watch creation
kubectl get aksclusters -w

# Check status
kubectl describe akscluster dev-cluster-001
```

### 3. Monitor Resources

```bash
# See all managed resources
kubectl get managed

# Check composite resource
kubectl get xakscluster

# Check individual resources
kubectl get resourcegroup
kubectl get virtualnetwork
kubectl get kubernetescluster
```

## Usage Examples

### Development Cluster

```yaml
apiVersion: platform.example.org/v1alpha1
kind: AKSCluster
metadata:
  name: dev-cluster
  namespace: development
spec:
  parameters:
    clusterName: dev-cluster
    size: small
    location: West Europe
    kubernetesVersion: "1.28"
    environment: dev
```

### Staging Cluster

```yaml
apiVersion: platform.example.org/v1alpha1
kind: AKSCluster
metadata:
  name: staging-cluster
  namespace: staging
spec:
  parameters:
    clusterName: staging-cluster
    size: medium
    location: North Europe
    kubernetesVersion: "1.28"
    environment: staging
```

### Production Cluster

```yaml
apiVersion: platform.example.org/v1alpha1
kind: AKSCluster
metadata:
  name: prod-cluster
  namespace: production
spec:
  parameters:
    clusterName: prod-cluster
    size: large
    location: West Europe
    kubernetesVersion: "1.28"
    environment: production
```

## Accessing the Cluster

### Get Kubeconfig

The composition creates a secret with kubeconfig:

```bash
# Get the secret name (clusterName-kubeconfig)
kubectl get secret dev-cluster-001-kubeconfig -n default

# Extract kubeconfig
kubectl get secret dev-cluster-001-kubeconfig -n default \
  -o jsonpath='{.data.kubeconfig}' | base64 -d > dev-cluster-kubeconfig

# Use it
export KUBECONFIG=dev-cluster-kubeconfig
kubectl get nodes
```

### Or use Azure CLI

```bash
# Get credentials via Azure CLI
az aks get-credentials \
  --resource-group rg-dev-cluster-001 \
  --name dev-cluster-001
```

## Customization

### Change Network CIDR

Edit `composition.yaml`:

```yaml
- name: virtualnetwork
  base:
    spec:
      forProvider:
        addressSpace:
          - 10.100.0.0/16  # Change this
```

### Add More Size Options

Edit `composition.yaml` patches:

```yaml
transforms:
  - type: map
    map:
      small: Standard_D2s_v3
      medium: Standard_D4s_v3
      large: Standard_D8s_v3
      xlarge: Standard_D16s_v3  # Add this
```

### Change Kubernetes Version

Edit `definition.yaml` to add version options:

```yaml
kubernetesVersion:
  type: string
  default: "1.28"
  enum:
    - "1.27"
    - "1.28"
    - "1.29"
```

### Add Node Labels

Edit `composition.yaml` AKS resource:

```yaml
defaultNodePool:
  - name: system
    nodeLabels:
      environment: dev
      nodepool: system
```

## Advanced Features

### Multiple Node Pools

Add user node pool to composition:

```yaml
- name: usernodepool
  base:
    apiVersion: containerservice.azure.upbound.io/v1beta1
    kind: KubernetesClusterNodePool
    spec:
      forProvider:
        mode: User
        vmSize: Standard_D4s_v3
```

### Private Cluster

Add to AKS cluster base:

```yaml
spec:
  forProvider:
    privateClusterEnabled: true
    privateClusterPublicFqdnEnabled: false
```

### Azure AD Integration

Add to AKS cluster base:

```yaml
spec:
  forProvider:
    azureActiveDirectoryRoleBasedAccessControl:
      - managed: true
        azureRbacEnabled: true
```

## Troubleshooting

### Claim Stays in Pending

```bash
# Check composite resource
kubectl describe xakscluster

# Check managed resources
kubectl get managed

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### Resources Not Creating

```bash
# Check composition
kubectl describe composition aks-cluster-standard

# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-containerservice
```

### Kubeconfig Secret Not Created

```bash
# Verify writeConnectionSecretToRef
kubectl get akscluster dev-cluster-001 -o yaml | grep -A5 writeConnection

# Check if AKS resource has connection details
kubectl get kubernetescluster -o yaml | grep -A10 writeConnection
```

## Cleanup

### Delete Cluster

```bash
# Delete the claim
kubectl delete akscluster dev-cluster-001

# Crossplane deletes all resources automatically
# Monitor deletion
kubectl get managed -w
```

### Verify Cleanup

```bash
# Check Azure resources are deleted
az group show --name rg-dev-cluster-001
# Should return: ResourceGroupNotFound
```

## Cost Estimates

|Size  |Monthly Cost|
|------|------------|
|small |~€150-180   |
|medium|~€300-360   |
|large |~€600-720   |

**Note**: Includes compute only. Add costs for:

- Data transfer
- Load balancers
- Storage
- Monitoring

## Best Practices

### 1. Use Namespaces

Organize claims by team or environment:

```bash
kubectl create namespace team-backend
kubectl apply -f claim.yaml -n team-backend
```

### 2. Set Resource Quotas

Limit number of clusters per namespace:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: cluster-quota
  namespace: team-backend
spec:
  hard:
    count/aksclusters.platform.example.org: "2"
```

### 3. Use Labels

Tag claims for organization:

```yaml
metadata:
  labels:
    team: backend
    cost-center: engineering
    project: api-platform
```

### 4. Version Control

Store claims in Git:

```bash
git add claims/dev-cluster.yaml
git commit -m "Add dev cluster"
git push
```

### 5. Monitor Costs

Tag all resources:

```yaml
spec:
  parameters:
    tags:
      cost-center: engineering
      owner: platform-team
```

## Integration with Applications

### Deploy Applications

```bash
# Get kubeconfig
kubectl get secret dev-cluster-001-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > kubeconfig

# Deploy app
kubectl --kubeconfig=kubeconfig apply -f app.yaml
```

### Use with Flux

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: app-deployment
  namespace: flux-system
spec:
  interval: 5m
  path: ./apps
  prune: true
  kubeConfig:
    secretRef:
      name: dev-cluster-001-kubeconfig
      namespace: default
```

## Next Steps

1. ✅ Install XRD and Composition
1. ✅ Create a dev cluster
1. ✅ Access the cluster
1. ⏳ Deploy applications
1. ⏳ Add monitoring
1. ⏳ Create staging/prod clusters

## Related Compositions

- [PostgreSQL Composition](../postgresql/) - Managed databases
- [Development Environment](../dev-environment/) - Complete dev stack

-----

*AKS Cluster Composition for learning-flux-aks-crossplane repository*
