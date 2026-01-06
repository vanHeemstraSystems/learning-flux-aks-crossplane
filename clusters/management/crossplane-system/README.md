# Crossplane System Configuration

This directory contains the Flux-managed Crossplane installation for the management cluster.

## Contents

|File                 |Purpose                                          |
|---------------------|-------------------------------------------------|
|`namespace.yaml`     |Creates the crossplane-system namespace          |
|`helmrepo.yaml`      |Adds the Crossplane Helm repository              |
|`helmrelease.yaml`   |Installs Crossplane via Helm with Azure providers|
|`providerconfig.yaml`|Configures Azure provider authentication         |
|`kustomization.yaml` |Kustomize configuration to apply all resources   |

## Prerequisites

Before applying these manifests:

1. **Flux must be installed** on the management cluster
1. **Azure credentials secret** must be created

## Installation Steps

### 1. Create Azure Credentials Secret

First, create a service principal for Crossplane:

```bash
# Set variables
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SP_NAME="crossplane-sp"

# Create service principal
az ad sp create-for-rbac \
  --name $SP_NAME \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth > azure-credentials.json

# Create Kubernetes secret
kubectl create secret generic azure-credentials \
  -n crossplane-system \
  --from-file=credentials=azure-credentials.json

# Verify secret
kubectl get secret -n crossplane-system azure-credentials
```

**Security Note**: Keep `azure-credentials.json` secure and delete it after creating the secret.

### 2. Apply via Flux

If using GitOps with Flux (recommended):

```bash
# Commit these files to your Git repository
git add clusters/management/crossplane-system/
git commit -m "Add Crossplane installation"
git push origin main

# Flux will automatically detect and apply changes
# Watch the reconciliation
flux get kustomizations --watch
```

### 3. Manual Apply (Alternative)

If applying manually:

```bash
# Apply kustomization
kubectl apply -k clusters/management/crossplane-system/

# Watch Crossplane installation
kubectl get pods -n crossplane-system --watch
```

## Verification

### Check Crossplane Installation

```bash
# Check pods
kubectl get pods -n crossplane-system

# Expected output:
# NAME                                      READY   STATUS
# crossplane-xxxx                          1/1     Running
# crossplane-rbac-manager-xxxx             1/1     Running
# provider-azure-compute-xxxx              1/1     Running
# provider-azure-containerservice-xxxx     1/1     Running
# provider-azure-network-xxxx              1/1     Running
# provider-azure-storage-xxxx              1/1     Running
# provider-azure-authorization-xxxx        1/1     Running
```

### Check Providers

```bash
# List all providers
kubectl get providers

# Check provider status
kubectl get provider provider-azure-network -o yaml

# All providers should show HEALTHY=True and INSTALLED=True
```

### Check ProviderConfig

```bash
# Verify ProviderConfig
kubectl get providerconfig

# Should show:
# NAME      AGE
# default   XXs
```

### Test with Simple Resource

Create a test resource group to verify everything works:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: azure.upbound.io/v1beta1
kind: ResourceGroup
metadata:
  name: test-crossplane
spec:
  forProvider:
    location: West Europe
  providerConfigRef:
    name: default
EOF

# Watch the resource
kubectl get resourcegroup test-crossplane --watch

# Check status
kubectl describe resourcegroup test-crossplane

# Verify in Azure
az group show --name test-crossplane

# Cleanup
kubectl delete resourcegroup test-crossplane
```

## Configuration Details

### Helm Chart Version

Current configuration uses Crossplane `>=1.14.0 <2.0.0`. This allows:

- Automatic patch updates (1.14.x)
- Blocks major version updates (stays on 1.x)

To pin to specific version:

```yaml
version: '1.14.5'
```

### Azure Providers

The following Azure providers are installed:

|Provider                       |Purpose   |Resources              |
|-------------------------------|----------|-----------------------|
|provider-azure-network         |Networking|VNet, Subnet, NSG, etc.|
|provider-azure-compute         |Compute   |VMs, Disks, etc.       |
|provider-azure-storage         |Storage   |Storage accounts, blobs|
|provider-azure-containerservice|AKS       |Kubernetes clusters    |
|provider-azure-authorization   |RBAC      |Role assignments       |

All providers use version `v0.42.1` from Upbound.

### Resource Limits

Configured resource limits:

**Crossplane Controller**:

- Requests: 100m CPU, 256Mi memory
- Limits: 500m CPU, 1Gi memory

**RBAC Manager**:

- Requests: 50m CPU, 128Mi memory
- Limits: 200m CPU, 512Mi memory

**Package Cache**:

- Size: 5Gi

Adjust these based on your workload in `helmrelease.yaml`.

### Features Enabled

- `--enable-composition-revisions`: Track composition changes
- `--enable-environment-configs`: Use environment configurations
- `--debug`: Enable debug logging
- Metrics: Prometheus metrics enabled

## Troubleshooting

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod -n crossplane-system <pod-name>

# Check logs
kubectl logs -n crossplane-system <pod-name>

# Common issues:
# - Image pull errors: Check network connectivity
# - Resource limits: Increase in helmrelease.yaml
```

### Provider Not Healthy

```bash
# Check provider status
kubectl describe provider provider-azure-network

# Check provider logs
kubectl logs -n crossplane-system \
  -l pkg.crossplane.io/provider=provider-azure-network

# Common issues:
# - Credentials invalid: Recreate azure-credentials secret
# - API quota exceeded: Check Azure subscription limits
```

### ProviderConfig Not Working

```bash
# Verify secret exists
kubectl get secret -n crossplane-system azure-credentials

# Check secret contents (base64 encoded)
kubectl get secret -n crossplane-system azure-credentials -o yaml

# Verify ProviderConfig references correct secret
kubectl get providerconfig default -o yaml

# Test with simple resource (see verification section above)
```

### Resources Not Creating

```bash
# Check resource status
kubectl describe <resource-type> <resource-name>

# Look for events and conditions
kubectl get events -n crossplane-system --sort-by='.lastTimestamp'

# Check if provider is healthy
kubectl get providers

# Verify Azure credentials have correct permissions
az role assignment list --assignee <service-principal-id>
```

## Updating Crossplane

### Update Core Version

Edit `helmrelease.yaml`:

```yaml
spec:
  chart:
    spec:
      version: '>=1.15.0 <2.0.0'  # Update to newer version
```

Commit and push. Flux will handle the upgrade.

### Update Providers

Edit `helmrelease.yaml`:

```yaml
spec:
  values:
    provider:
      packages:
        - xpkg.upbound.io/upbound/provider-azure-network:v0.43.0  # New version
```

### Manual Upgrade

```bash
# If not using Flux
helm upgrade crossplane \
  crossplane-stable/crossplane \
  --namespace crossplane-system \
  --version 1.15.0
```

## Best Practices

1. **Version Pinning**: Pin provider versions for production stability
1. **Resource Limits**: Set appropriate limits based on workload
1. **Monitoring**: Enable metrics and integrate with Prometheus
1. **Credentials Rotation**: Regularly rotate service principal credentials
1. **Backup**: Keep backups of ProviderConfig and important compositions
1. **GitOps**: Always use Flux to manage Crossplane configuration

## Integration with Examples

Once Crossplane is installed, you can deploy the examples:

```bash
# Deploy simple AKS example
kubectl apply -k ../../examples/simple-aks/

# Or via GitOps (recommended)
git add examples/simple-aks/
git commit -m "Deploy AKS cluster via Crossplane"
git push origin main
```

## Next Steps

After Crossplane is installed and verified:

1. **Create compositions**: Define reusable infrastructure patterns
1. **Deploy workload clusters**: Use examples to provision AKS clusters
1. **Implement XRDs**: Build platform abstractions for developers
1. **Add monitoring**: Integrate with Grafana for observability

See the main repository documentation for detailed guides.

## Security Considerations

- **Secret Management**: azure-credentials contains sensitive data
  - Use sealed-secrets or external-secrets in production
  - Rotate credentials regularly
  - Limit service principal permissions to minimum required
- **RBAC**: ProviderConfig uses cluster-wide permissions
  - Consider namespace-scoped ProviderConfigs for multi-tenancy
  - Implement proper Kubernetes RBAC policies
- **Network Policies**: Consider restricting Crossplane pod network access

## Cost Awareness

Crossplane itself is free, but created resources incur Azure costs:

- Monitor resources created via Crossplane
- Implement resource quotas and limits
- Use Azure Cost Management to track spending
- Clean up test resources promptly

-----

*Crossplane system configuration for learning-flux-aks-crossplane repository*
