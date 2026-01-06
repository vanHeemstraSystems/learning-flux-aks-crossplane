# Crossplane Azure Providers

This directory contains the Azure provider configuration and setup scripts for Crossplane.

## Files

|File                         |Purpose                                  |
|-----------------------------|-----------------------------------------|
|`provider-azure.yaml`        |Azure provider installation              |
|`provider-config-azure.yaml` |ProviderConfig for authentication        |
|`create-service-principal.sh`|Helper script to create Azure credentials|
|`README.md`                  |This file                                |

## Quick Start

### 1. Install Crossplane

If not already installed:

```bash
# Add Crossplane Helm repo
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Install Crossplane
helm install crossplane \
  crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace

# Verify installation
kubectl get pods -n crossplane-system
```

### 2. Create Azure Service Principal

Use the provided script:

```bash
# Make script executable
chmod +x create-service-principal.sh

# Run script
./create-service-principal.sh
```

Or create manually:

```bash
# Login to Azure
az login

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create service principal
az ad sp create-for-rbac \
  --name crossplane-sp \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth > azure-credentials.json

# Create Kubernetes secret
kubectl create secret generic azure-credentials \
  -n crossplane-system \
  --from-file=credentials=azure-credentials.json

# Delete credentials file
rm azure-credentials.json
```

### 3. Install Azure Providers

```bash
# Install provider family (recommended)
kubectl apply -f provider-azure.yaml

# Wait for providers to be installed
kubectl get providers -w

# Expected output (after a few minutes):
# NAME                              INSTALLED   HEALTHY   PACKAGE
# upbound-provider-family-azure     True        True      xpkg.upbound.io/...
```

### 4. Configure Provider Authentication

```bash
# Apply ProviderConfig
kubectl apply -f provider-config-azure.yaml

# Verify ProviderConfig
kubectl get providerconfig
```

### 5. Verify Setup

```bash
# Check all providers are healthy
kubectl get providers

# Check ProviderConfig
kubectl describe providerconfig default

# Test by creating a simple resource
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

# Watch resource creation
kubectl get resourcegroup test-crossplane-rg -w

# Clean up test
kubectl delete resourcegroup test-crossplane-rg
```

## Provider Options

### Option 1: Provider Family (Recommended)

The provider family automatically installs all Azure providers:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: upbound-provider-family-azure
spec:
  package: xpkg.upbound.io/upbound/provider-family-azure:v0.42.1
```

**Includes**:

- provider-azure (core)
- provider-azure-network
- provider-azure-compute
- provider-azure-containerservice
- provider-azure-storage
- provider-azure-dbforpostgresql
- provider-azure-authorization

**Pros**:

- ✅ Simple - one resource installs everything
- ✅ All providers use same version
- ✅ Automatic dependency management
- ✅ Recommended for most use cases

**Cons**:

- ❌ Larger download size
- ❌ All providers installed even if not needed

### Option 2: Individual Providers

Install only specific providers you need:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-network
spec:
  package: xpkg.upbound.io/upbound/provider-azure-network:v0.42.1
```

**Pros**:

- ✅ Smaller footprint
- ✅ Only install what you need
- ✅ Faster installation

**Cons**:

- ❌ Must manage dependencies manually
- ❌ Version compatibility between providers

## Available Providers

|Provider |Package                                |Purpose          |
|---------|---------------------------------------|-----------------|
|Family   |upbound/provider-family-azure          |All providers    |
|Core     |upbound/provider-azure                 |Base provider    |
|Network  |upbound/provider-azure-network         |VNet, Subnet, NSG|
|Compute  |upbound/provider-azure-compute         |VMs, Disks       |
|Container|upbound/provider-azure-containerservice|AKS              |
|Database |upbound/provider-azure-dbforpostgresql |PostgreSQL       |
|Storage  |upbound/provider-azure-storage         |Storage Accounts |
|Auth     |upbound/provider-azure-authorization   |RBAC             |

## Provider Versions

Current version: **v0.42.1**

### Checking Latest Version

```bash
# Check marketplace for latest version
# Visit: https://marketplace.upbound.io/providers/upbound/provider-family-azure

# Or use upbound CLI
up repository list-versions upbound/provider-family-azure
```

### Upgrading Providers

```bash
# Edit provider-azure.yaml to new version
# Then apply:
kubectl apply -f provider-azure.yaml

# Monitor upgrade
kubectl get providers -w

# Check provider status
kubectl describe provider upbound-provider-family-azure
```

## ProviderConfig

The ProviderConfig tells providers how to authenticate with Azure.

### Default Configuration

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

### Multiple ProviderConfigs

For multi-subscription scenarios:

```yaml
---
# Production subscription
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
# Development subscription
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
    name: production  # or development
```

## Authentication Methods

### Method 1: Service Principal (Recommended)

Current setup using service principal with client secret.

**Pros**:

- ✅ Simple to set up
- ✅ Works everywhere
- ✅ Easy to rotate

**Cons**:

- ❌ Requires secret management
- ❌ Credentials in cluster

### Method 2: Managed Identity (Advanced)

For AKS clusters with workload identity:

```yaml
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
```

**Requires**:

- AKS with OIDC issuer enabled
- Workload identity configured
- Federated credentials set up

**Pros**:

- ✅ No secrets to manage
- ✅ Automatic credential rotation
- ✅ More secure

**Cons**:

- ❌ More complex setup
- ❌ AKS-only

## Troubleshooting

### Providers Not Installing

```bash
# Check provider status
kubectl get providers
kubectl describe provider upbound-provider-family-azure

# Check events
kubectl get events -n crossplane-system --sort-by='.lastTimestamp'

# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure
```

Common issues:

- Network connectivity to package registry
- Insufficient permissions
- Version conflicts

### Authentication Failures

```bash
# Verify secret exists
kubectl get secret -n crossplane-system azure-credentials

# Check secret contents (base64 encoded)
kubectl get secret -n crossplane-system azure-credentials -o yaml

# Test service principal manually
az login --service-principal \
  -u <CLIENT_ID> \
  -p <CLIENT_SECRET> \
  --tenant <TENANT_ID>
```

### Resources Not Creating

```bash
# Check resource status
kubectl describe <resource-type> <resource-name>

# Check provider health
kubectl get providers

# Check ProviderConfig
kubectl get providerconfig
kubectl describe providerconfig default

# Check provider logs
kubectl logs -n crossplane-system \
  -l pkg.crossplane.io/provider=provider-azure-network -f
```

## Security Best Practices

### 1. Limit Service Principal Permissions

Instead of Contributor on entire subscription:

```bash
# Create resource group first
az group create --name crossplane-managed --location westeurope

# Scope service principal to specific resource group
az ad sp create-for-rbac \
  --name crossplane-sp \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/crossplane-managed
```

### 2. Use Separate Service Principals

Different SPs for different environments:

```bash
# Production
az ad sp create-for-rbac \
  --name crossplane-prod-sp \
  --role Contributor \
  --scopes /subscriptions/$PROD_SUBSCRIPTION_ID

# Development
az ad sp create-for-rbac \
  --name crossplane-dev-sp \
  --role Contributor \
  --scopes /subscriptions/$DEV_SUBSCRIPTION_ID
```

### 3. Rotate Credentials Regularly

```bash
# Reset service principal credentials
az ad sp credential reset --name crossplane-sp

# Update Kubernetes secret
kubectl create secret generic azure-credentials \
  -n crossplane-system \
  --from-file=credentials=azure-credentials.json \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 4. Use Azure Key Vault (Advanced)

Store credentials in Azure Key Vault and use External Secrets Operator.

### 5. Enable Audit Logging

```bash
# Enable Azure Activity Log
az monitor log-profiles create \
  --name crossplane-audit \
  --locations westeurope \
  --categories Write Delete Action
```

## Monitoring

### Provider Health

```bash
# Watch provider status
watch kubectl get providers

# Get detailed status
kubectl get provider upbound-provider-family-azure -o yaml

# Check provider controller logs
kubectl logs -n crossplane-system \
  deployment/upbound-provider-family-azure-xxxxx
```

### Resource Monitoring

```bash
# List all managed resources
kubectl get managed

# Filter by provider
kubectl get managed -l crossplane.io/provider=provider-azure-network

# Check specific resource
kubectl describe resourcegroup my-rg
```

### Metrics

Providers expose Prometheus metrics:

```bash
# Port forward to provider
kubectl port-forward -n crossplane-system \
  deployment/provider-azure-xxxxx 8080:8080

# Scrape metrics
curl localhost:8080/metrics
```

## Cleanup

### Remove Test Resources

```bash
# Delete all test resources
kubectl delete resourcegroup --all

# Or specific resources
kubectl delete resourcegroup test-crossplane-rg
```

### Uninstall Providers

```bash
# Delete ProviderConfig first
kubectl delete providerconfig default

# Delete providers
kubectl delete provider upbound-provider-family-azure

# Delete secret
kubectl delete secret -n crossplane-system azure-credentials
```

### Delete Service Principal

```bash
# List service principals
az ad sp list --display-name crossplane-sp

# Delete service principal
az ad sp delete --id <SERVICE_PRINCIPAL_ID>
```

## Next Steps

After setting up providers:

1. ✅ Test with simple ResourceGroup
1. ⏳ Create compositions for your infrastructure
1. ⏳ Set up monitoring and alerts
1. ⏳ Implement backup/disaster recovery
1. ⏳ Configure RBAC for team access

## Resources

- [Crossplane Documentation](https://docs.crossplane.io/)
- [Azure Provider Docs](https://marketplace.upbound.io/providers/upbound/provider-family-azure/)
- [Upbound Marketplace](https://marketplace.upbound.io/)
- [Azure RBAC Docs](https://docs.microsoft.com/en-us/azure/role-based-access-control/)

-----

*Provider configuration for learning-flux-aks-crossplane repository*
