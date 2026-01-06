# Crossplane Claims Examples

This directory contains example Crossplane resource claims that demonstrate how to provision Azure infrastructure using Kubernetes manifests.

## What are Claims?

**Claims** are Kubernetes resources that request infrastructure to be provisioned. Think of them as “orders” for cloud resources that Crossplane fulfills by creating actual Azure resources.

```
Developer creates → Crossplane Claim (YAML) → Crossplane provisions → Azure Resource
```

## Directory Structure

```
crossplane/claims/examples/
├── resourcegroup-claim.yaml      # Simple resource group
├── storage-account-claim.yaml    # Storage account with security
├── network-claim.yaml            # Complete VNet, subnets, NSG
├── postgresql-claim.yaml         # PostgreSQL server and database
├── kustomization.yaml           # Kustomize configuration
└── README.md                    # This file
```

## Available Examples

### 1. Resource Group (`resourcegroup-claim.yaml`)

**Purpose**: Creates an Azure resource group

**Use case**: Foundation for all other resources

**Resources created**:

- 1 Resource Group in West Europe

**Deploy time**: ~30 seconds

**Cost**: Free (resource groups have no cost)

**Example**:

```yaml
apiVersion: azure.upbound.io/v1beta1
kind: ResourceGroup
metadata:
  name: example-rg-claim
spec:
  forProvider:
    location: West Europe
```

### 2. Storage Account (`storage-account-claim.yaml`)

**Purpose**: Creates a secure storage account

**Use case**: Application data storage, backups, file shares

**Resources created**:

- 1 Storage Account (Standard LRS, Hot tier)
- Network rules configured
- HTTPS-only access
- Encryption enabled

**Deploy time**: ~2 minutes

**Cost**: ~€0.50/month for 5GB

**Features**:

- ✅ HTTPS-only traffic
- ✅ Minimum TLS 1.2
- ✅ Infrastructure encryption
- ✅ Private blob access
- ✅ Network restrictions

### 3. Network Setup (`network-claim.yaml`)

**Purpose**: Creates complete network infrastructure

**Use case**: Network foundation for workloads and AKS clusters

**Resources created**:

- 1 Virtual Network (10.100.0.0/16)
- 2 Subnets (workload + AKS)
- 1 Network Security Group
- 1 Security Rule (HTTPS allow)
- NSG association with subnet

**Deploy time**: ~3 minutes

**Cost**: ~€1-2/month

**Features**:

- ✅ Service endpoints enabled
- ✅ NSG for security
- ✅ Separate subnets for different workloads
- ✅ HTTPS ingress rule

### 4. PostgreSQL Database (`postgresql-claim.yaml`)

**Purpose**: Creates a managed PostgreSQL database

**Use case**: Application database, data persistence

**Resources created**:

- 1 PostgreSQL Server (v14, Basic tier)
- 1 Database
- 1 Firewall rule

**Deploy time**: ~5-8 minutes

**Cost**: ~€25-30/month (Basic B_Gen5_1)

**Features**:

- ✅ SSL enforced
- ✅ TLS 1.2 minimum
- ✅ 7-day backup retention
- ✅ Auto-grow enabled
- ✅ Private network access

## Prerequisites

Before deploying these examples:

### 1. Crossplane Installed

```bash
# Check Crossplane is running
kubectl get pods -n crossplane-system

# Check providers are healthy
kubectl get providers
```

### 2. Azure Credentials Configured

```bash
# Verify ProviderConfig exists
kubectl get providerconfig

# Check it's configured
kubectl describe providerconfig default
```

### 3. Required Secrets (for PostgreSQL example)

```bash
# Create PostgreSQL admin password secret
kubectl create secret generic postgres-admin-password \
  -n crossplane-system \
  --from-literal=password='YourSecurePassword123!'
```

## Deployment Guide

### Method 1: Deploy Individual Example

```bash
# Apply single example
kubectl apply -f resourcegroup-claim.yaml

# Watch it provision
kubectl get resourcegroup example-rg-claim --watch

# Check status
kubectl describe resourcegroup example-rg-claim

# Verify in Azure
az group show --name example-rg-claim
```

### Method 2: Deploy Multiple Examples

Edit `kustomization.yaml` to uncomment the resources you want:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - resourcegroup-claim.yaml    # Uncomment this
  - network-claim.yaml          # Uncomment this
  # - storage-account-claim.yaml  # Leave commented
```

Then apply:

```bash
# Apply selected examples
kubectl apply -k crossplane/claims/examples/

# Watch all resources
kubectl get managed --watch
```

### Method 3: GitOps with Flux

Add to your repository structure:

```bash
# Copy examples to your infrastructure directory
cp -r crossplane/claims/examples infrastructure/test-resources

# Commit
git add infrastructure/test-resources
git commit -m "Add test resource claims"
git push origin main

# Flux will deploy automatically
flux get kustomizations --watch
```

## Verification

### Check Kubernetes Resources

```bash
# List all managed resources
kubectl get managed

# Check specific resource type
kubectl get resourcegroup
kubectl get virtualnetwork
kubectl get storageaccount

# Detailed status
kubectl describe resourcegroup example-rg-claim
```

### Check Azure Resources

```bash
# Resource group
az group show --name example-rg-claim

# Storage account
az storage account show \
  --resource-group example-rg-claim \
  --name <storage-account-name>

# Virtual network
az network vnet show \
  --resource-group example-rg-claim \
  --name example-vnet-claim

# PostgreSQL server
az postgres server show \
  --resource-group example-rg-claim \
  --name example-postgres-claim
```

### Check Resource Status

```bash
# Get resource status
kubectl get resourcegroup example-rg-claim -o jsonpath='{.status.conditions}'

# Check if resource is ready
kubectl get resourcegroup example-rg-claim -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'

# Should output: True
```

## Resource Dependencies

These examples have dependencies on each other:

```
┌─────────────────────┐
│  Resource Group     │ ← Start here (required for all)
└──────────┬──────────┘
           │
           ├───────────────┬───────────────┐
           │               │               │
           ▼               ▼               ▼
    ┌───────────┐   ┌──────────┐   ┌──────────────┐
    │  Network  │   │ Storage  │   │ PostgreSQL   │
    │  Setup    │   │ Account  │   │ (needs net)  │
    └───────────┘   └──────────┘   └──────────────┘
```

**Deployment order**:

1. Deploy `resourcegroup-claim.yaml` first
1. Wait for it to be ready (~30 seconds)
1. Deploy network, storage, or database examples
1. Each will reference the resource group

## Customization

### Change Location

Edit any manifest to change the Azure region:

```yaml
spec:
  forProvider:
    location: North Europe  # Change from West Europe
```

### Change Names

Update metadata names to match your naming convention:

```yaml
metadata:
  name: prod-rg-westeu-001  # Instead of example-rg-claim
```

**Note**: Also update references in dependent resources!

### Add Tags

Add custom tags to resources:

```yaml
spec:
  forProvider:
    tags:
      environment: production
      cost-center: platform
      owner: platform-team
      project: learning
```

### Adjust Resource Sizes

For storage account:

```yaml
spec:
  forProvider:
    accountTier: Premium      # Instead of Standard
    accountReplicationType: ZRS  # Instead of LRS
```

For PostgreSQL:

```yaml
spec:
  forProvider:
    skuName: GP_Gen5_2       # General Purpose, 2 vCores
    storageMb: 102400        # 100 GB instead of 5 GB
```

## Troubleshooting

### Resource Not Creating

```bash
# Check resource status
kubectl describe <resource-type> <resource-name>

# Look for events and conditions
kubectl get events --sort-by='.lastTimestamp' | grep <resource-name>

# Check Crossplane logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-network -f
```

### Common Issues

**Issue**: “ResourceGroup not found”

```
Solution: Deploy resource group first, wait for it to be Ready
```

**Issue**: “ProviderConfig not found”

```bash
# Check ProviderConfig exists
kubectl get providerconfig

# If missing, create it (see crossplane-system docs)
```

**Issue**: “Insufficient permissions”

```
Solution: Verify Azure service principal has Contributor role
kubectl get secret -n crossplane-system azure-credentials
```

**Issue**: “Name already exists”

```
Solution: Resource names must be unique in Azure
Change the metadata.name or delete existing Azure resource
```

### Debug Mode

Enable verbose logging:

```bash
# Check current args
kubectl get deployment -n crossplane-system crossplane -o yaml | grep args

# Patch to add verbose logging
kubectl patch deployment crossplane -n crossplane-system \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--debug"}]'
```

## Cleanup

### Delete Individual Resource

```bash
# Delete Kubernetes resource
kubectl delete resourcegroup example-rg-claim

# Crossplane will delete Azure resource automatically
# Verify deletion in Azure
az group show --name example-rg-claim
```

### Delete All Examples

```bash
# Delete all managed resources
kubectl delete -k crossplane/claims/examples/

# Or delete individually
kubectl delete -f resourcegroup-claim.yaml
kubectl delete -f network-claim.yaml
kubectl delete -f storage-account-claim.yaml
kubectl delete -f postgresql-claim.yaml
```

### Force Cleanup

If resources are stuck:

```bash
# Remove finalizer
kubectl patch resourcegroup example-rg-claim \
  -p '{"metadata":{"finalizers":[]}}' \
  --type=merge

# Then delete
kubectl delete resourcegroup example-rg-claim
```

## Cost Estimates

|Resource       |Configuration    |Monthly Cost|
|---------------|-----------------|------------|
|Resource Group |N/A              |Free        |
|Storage Account|Standard LRS, 5GB|~€0.50      |
|Virtual Network|/16 CIDR         |~€1-2       |
|PostgreSQL     |Basic B_Gen5_1   |~€25-30     |
|**Total**      |All examples     |**~€27-33** |

**Daily cost**: ~€1/day for all examples

**Important**: Delete resources when not in use to avoid charges!

## Best Practices

### 1. Use Meaningful Names

```yaml
✅ Good: prod-webapp-rg-westeu
❌ Bad: test123, my-rg, rg1
```

### 2. Always Tag Resources

```yaml
tags:
  environment: dev
  project: learning
  owner: platform-team
  cost-center: engineering
  managed-by: crossplane
```

### 3. Use Selectors for Relationships

Instead of hard-coding names:

```yaml
# Use selector
virtualNetworkNameSelector:
  matchLabels:
    app: myapp

# Instead of
virtualNetworkName: hardcoded-name
```

### 4. Document Dependencies

Add comments showing what resources depend on others:

```yaml
# Depends on: example-rg-claim, example-vnet-claim
```

### 5. Set Appropriate Deletion Policies

```yaml
spec:
  deletionPolicy: Delete  # or Orphan to keep Azure resource
```

### 6. Use Secrets for Sensitive Data

Never put passwords in YAML:

```yaml
# ✅ Good
administratorLoginPasswordSecretRef:
  name: postgres-password
  key: password

# ❌ Bad
administratorLoginPassword: "mypassword123"
```

## Integration with Applications

### Connect Application to PostgreSQL

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  DB_HOST: example-postgres-claim.postgres.database.azure.com
  DB_NAME: example-db-claim
  DB_USER: psqladmin
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
stringData:
  DB_PASSWORD: YourSecurePassword123!
```

### Connect Application to Storage

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: storage-config
data:
  STORAGE_ACCOUNT: <storage-account-name>
  CONTAINER_NAME: myapp-data
```

## Next Steps

1. ✅ Deploy resource group example
1. ✅ Verify it creates successfully
1. ✅ Deploy network example
1. ⏳ Create your own claims
1. ⏳ Build compositions for reusable patterns
1. ⏳ Integrate with applications

See the main repository documentation for composition guides.

## Related Documentation

- [Crossplane System Setup](../../clusters/management/crossplane-system/README.md)
- [Simple AKS Example](../../examples/simple-aks/README.md)
- [Crossplane Documentation](https://docs.crossplane.io/)
- [Azure Provider Reference](https://marketplace.upbound.io/providers/upbound/provider-azure/)

-----

*Example claims for learning-flux-aks-crossplane repository*
