# 05 - Configure Azure Provider

## Overview

This guide configures the Crossplane Azure Provider, enabling Crossplane to provision and manage Azure resources from your Kubernetes cluster using declarative manifests.

## Prerequisites

Before proceeding, ensure:

- ✅ Crossplane is installed ([04 - Install Crossplane](./04-install-crossplane.md))
- ✅ Azure CLI is configured with appropriate permissions
- ✅ You have Contributor access to your Azure subscription

Verify Crossplane is running:

```bash
kubectl get pods -n crossplane-system
flux get helmreleases -n crossplane-system
```

## Azure Provider Architecture

```
┌────────────────────────────────────────────────────┐
│         Crossplane Core (crossplane-system)        │
│  ┌──────────────────────────────────────────────┐ │
│  │      Provider-Azure Family (Upjet)           │ │
│  │  ┌────────────────────────────────────────┐  │ │
│  │  │  Managed Resources (800+ CRDs):        │  │ │
│  │  │  - ResourceGroup                       │  │ │
│  │  │  - VirtualNetwork                      │  │ │
│  │  │  - Subnet                              │  │ │
│  │  │  - KubernetesCluster (AKS)            │  │ │
│  │  │  - StorageAccount                      │  │ │
│  │  │  - PostgreSQL, MySQL, CosmosDB...     │  │ │
│  │  └────────────────────────────────────────┘  │ │
│  └──────────────────────────────────────────────┘ │
└────────────────────┬───────────────────────────────┘
                     │ Service Principal
                     │ Authentication
                     ▼
            ┌────────────────────┐
            │   Azure Cloud API  │
            │     Resources      │
            └────────────────────┘
```

## Authentication Setup

### Step 1: Create Azure Service Principal

Create a service principal that Crossplane will use for Azure authentication:

```bash
# Get your subscription ID
export AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create service principal with descriptive name
export SP_NAME="crossplane-sp-$(date +%s)"

SP_JSON=$(az ad sp create-for-rbac \
  --name "${SP_NAME}" \
  --role Contributor \
  --scopes "/subscriptions/${AZURE_SUBSCRIPTION_ID}" \
  --query "{clientId: appId, clientSecret: password, tenantId: tenant, subscriptionId: '${AZURE_SUBSCRIPTION_ID}'}" \
  -o json)

# Extract values
export AZURE_CLIENT_ID=$(echo $SP_JSON | jq -r .clientId)
export AZURE_CLIENT_SECRET=$(echo $SP_JSON | jq -r .clientSecret)
export AZURE_TENANT_ID=$(echo $SP_JSON | jq -r .tenantId)

# Display values (save these securely!)
echo "==================================="
echo "Subscription ID: $AZURE_SUBSCRIPTION_ID"
echo "Client ID: $AZURE_CLIENT_ID"
echo "Tenant ID: $AZURE_TENANT_ID"
echo "Client Secret: $AZURE_CLIENT_SECRET"
echo "==================================="
```

**⚠️ Security Note**: Store these credentials securely. Never commit them to Git.

### Step 2: Create Credentials File

```bash
cat > azure-credentials.json <<EOF
{
  "clientId": "${AZURE_CLIENT_ID}",
  "clientSecret": "${AZURE_CLIENT_SECRET}",
  "subscriptionId": "${AZURE_SUBSCRIPTION_ID}",
  "tenantId": "${AZURE_TENANT_ID}",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
EOF
```

### Step 3: Create Kubernetes Secret

```bash
# Create secret in crossplane-system namespace
kubectl create secret generic azure-credentials \
  -n crossplane-system \
  --from-file=credentials=./azure-credentials.json

# Verify secret creation
kubectl get secret azure-credentials -n crossplane-system

# Clean up local credentials file
rm azure-credentials.json
```

## Install Azure Provider via Flux

### Understanding Provider Families

Upbound provides modular Azure providers instead of one monolithic provider:

**Family Providers (Recommended)**:

- `provider-azure-network` - VNet, Subnet, NSG, Load Balancers
- `provider-azure-compute` - VMs, Disks, Availability Sets
- `provider-azure-containerservice` - AKS clusters
- `provider-azure-storage` - Storage Accounts, Blobs
- `provider-azure-sql` - Azure SQL, MySQL, PostgreSQL
- `provider-azure-managedidentity` - Managed Identities

**Benefits**: Faster installation, smaller footprint, install only what you need.

### Step 1: Create Provider Manifest

For AKS deployment, we need these providers:

Create `infrastructure/crossplane/provider-azure.yaml`:

```yaml
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-network
spec:
  package: xpkg.upbound.io/upbound/provider-azure-network:v0.42.0
  packagePullPolicy: IfNotPresent
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-compute
spec:
  package: xpkg.upbound.io/upbound/provider-azure-compute:v0.42.0
  packagePullPolicy: IfNotPresent
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-containerservice
spec:
  package: xpkg.upbound.io/upbound/provider-azure-containerservice:v0.42.0
  packagePullPolicy: IfNotPresent
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-managedidentity
spec:
  package: xpkg.upbound.io/upbound/provider-azure-managedidentity:v0.42.0
  packagePullPolicy: IfNotPresent
```

### Step 2: Create ProviderConfig

Create `infrastructure/crossplane/providerconfig.yaml`:

```yaml
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: azure-credentials
      key: credentials
```

### Step 3: Update Kustomization

Update `infrastructure/crossplane/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: crossplane-system

resources:
  - namespace.yaml
  - helmrepo.yaml
  - helmrelease.yaml
  - provider-azure.yaml
  - providerconfig.yaml
```

### Step 4: Commit and Deploy

```bash
# Add files
git add infrastructure/crossplane/

# Commit
git commit -m "feat: add Azure provider configuration"

# Push
git push

# Watch deployment
flux reconcile kustomization infrastructure --with-source
kubectl get providers --watch
```

### Step 5: Verify Provider Installation

Wait for providers to become healthy (2-5 minutes):

```bash
# Check provider status
kubectl get providers

# Expected output:
# NAME                              INSTALLED   HEALTHY   PACKAGE
# provider-azure-network            True        True      xpkg.upbound.io/upbound/provider-azure-network:v0.42.0
# provider-azure-compute            True        True      xpkg.upbound.io/upbound/provider-azure-compute:v0.42.0
# provider-azure-containerservice   True        True      xpkg.upbound.io/upbound/provider-azure-containerservice:v0.42.0
# provider-azure-managedidentity    True        True      xpkg.upbound.io/upbound/provider-azure-managedidentity:v0.42.0

# View provider pods
kubectl get pods -n crossplane-system | grep provider
```

## Verification

### 1. Verify Provider CRDs

```bash
# List Azure CRDs
kubectl get crds | grep azure.upbound.io

# Should see CRDs like:
# resourcegroups.azure.upbound.io
# virtualnetworks.network.azure.upbound.io
# subnets.network.azure.upbound.io
# kubernetesclusters.containerservice.azure.upbound.io
# storageaccounts.storage.azure.upbound.io
```

### 2. Check ProviderConfig

```bash
# Verify ProviderConfig
kubectl get providerconfigs

# Get details
kubectl describe providerconfig default
```

### 3. Test Provider Connectivity

Create a test resource group to verify authentication:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: azure.upbound.io/v1beta1
kind: ResourceGroup
metadata:
  name: test-crossplane-rg
spec:
  forProvider:
    location: West Europe
  providerConfigRef:
    name: default
EOF

# Watch resource creation (takes ~30 seconds)
kubectl get resourcegroup test-crossplane-rg --watch

# Expected: STATUS should become "Available" and READY should be "True"

# Verify in Azure
az group show --name test-crossplane-rg

# Clean up test
kubectl delete resourcegroup test-crossplane-rg
```

## Provider Configuration Options

### Multiple ProviderConfigs

You can create separate ProviderConfigs for different environments:

```yaml
---
# Production credentials
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: production
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: azure-credentials-prod
      key: credentials
---
# Development credentials
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: development
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: azure-credentials-dev
      key: credentials
```

Use in resources:

```yaml
spec:
  providerConfigRef:
    name: development  # or production
```

## Troubleshooting

### Issue: Provider Not Becoming Healthy

```bash
# Check provider pod status
kubectl get pods -n crossplane-system | grep provider-azure

# Check provider logs
kubectl logs -n crossplane-system <provider-pod-name>

# Check provider installation details
kubectl describe provider provider-azure-network
```

**Common Causes**:

- Image pull errors (check internet connectivity)
- Insufficient cluster resources
- Previous provider installation conflicts

### Issue: Authentication Failures

```bash
# Verify secret exists
kubectl get secret azure-credentials -n crossplane-system

# Check secret content (base64 encoded)
kubectl get secret azure-credentials -n crossplane-system -o yaml

# Test service principal manually
az login --service-principal \
  -u $AZURE_CLIENT_ID \
  -p $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID

# Verify permissions
az role assignment list --assignee $AZURE_CLIENT_ID
```

### Issue: Resource Creation Fails

```bash
# Check resource status
kubectl describe <resource-type> <resource-name>

# Check events
kubectl get events --sort-by='.lastTimestamp' | grep <resource-name>

# View provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-network
```

## Best Practices

### 1. Use Least Privilege

Create a custom role with minimum required permissions:

```bash
# Create custom role definition
cat > crossplane-role.json <<EOF
{
  "Name": "Crossplane AKS Manager",
  "Description": "Minimal permissions for Crossplane to manage AKS and networking",
  "Actions": [
    "Microsoft.ContainerService/managedClusters/*",
    "Microsoft.Network/virtualNetworks/*",
    "Microsoft.Network/networkSecurityGroups/*",
    "Microsoft.Resources/resourceGroups/*",
    "Microsoft.ManagedIdentity/userAssignedIdentities/*"
  ],
  "NotActions": [],
  "AssignableScopes": ["/subscriptions/${AZURE_SUBSCRIPTION_ID}"]
}
EOF

# Create role
az role definition create --role-definition crossplane-role.json

# Assign role to service principal
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role "Crossplane AKS Manager" \
  --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}"
```

### 2. Rotate Credentials Regularly

```bash
# Reset service principal credentials
az ad sp credential reset --id $AZURE_CLIENT_ID

# Update Kubernetes secret
kubectl create secret generic azure-credentials \
  -n crossplane-system \
  --from-file=credentials=./azure-credentials.json \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 3. Monitor Provider Health

```bash
# Add to monitoring script
kubectl get providers --watch

# Check resource status periodically
kubectl get managed --all-namespaces
```

### 4. Pin Provider Versions

Always pin versions in production:

```yaml
spec:
  package: xpkg.upbound.io/upbound/provider-azure-network:v0.42.0
  # NOT: :latest or :v0.42
```

## Additional Providers (Optional)

Add more providers as needed:

```yaml
---
# Storage provider
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-storage
spec:
  package: xpkg.upbound.io/upbound/provider-azure-storage:v0.42.0
---
# SQL provider
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-sql
spec:
  package: xpkg.upbound.io/upbound/provider-azure-sql:v0.42.0
---
# Key Vault provider
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-keyvault
spec:
  package: xpkg.upbound.io/upbound/provider-azure-keyvault:v0.42.0
```

## Next Steps

With the Azure provider configured, you’re ready to provision Azure resources!

👉 **[06 - Provision AKS with Crossplane](./06-provision-aks.md)**

This will cover:

- Creating resource groups
- Configuring virtual networks
- Provisioning AKS clusters
- Accessing provisioned clusters

## Additional Resources

- [Upbound Azure Provider Documentation](https://marketplace.upbound.io/providers/upbound/provider-azure)
- [Azure Provider Examples](https://github.com/upbound/provider-azure/tree/main/examples)
- [Crossplane Authentication Guide](https://docs.crossplane.io/latest/concepts/providers/#provider-credentials)
- [Azure Service Principal Best Practices](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal)

-----

*Estimated time: 25-35 minutes*
