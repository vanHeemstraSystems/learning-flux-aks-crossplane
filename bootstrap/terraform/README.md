# Terraform Bootstrap - AKS Management Cluster

This directory contains Terraform configuration for creating the management AKS cluster that will run Flux and Crossplane.

## Overview

This Terraform configuration creates:

- Azure Resource Group
- Log Analytics Workspace for monitoring
- AKS Cluster with:
  - System-assigned managed identity
  - Azure CNI networking
  - Calico network policies
  - Cluster autoscaler
  - OIDC issuer (for Crossplane workload identity)
  - Azure AD RBAC integration
- Optional: Azure Container Registry

## Prerequisites

- Terraform >= 1.6.0
- Azure CLI logged in (`az login`)
- Appropriate Azure permissions (Contributor role)

## Quick Start

### 1. Configure Variables

Copy the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
subscription_id     = "your-subscription-id"
resource_group_name = "rg-flux-aks-learning"
location            = "westeurope"
cluster_name        = "aks-management"
```

**Important**: Never commit `terraform.tfvars` - it’s in `.gitignore`.

### 2. Initialize Terraform

```bash
terraform init
```

This downloads the Azure provider and initializes the backend.

### 3. Plan the Deployment

```bash
terraform plan
```

Review the resources that will be created. Expected resources:

- 1 Resource Group
- 1 Log Analytics Workspace
- 1 AKS Cluster
- 1 Role Assignment
- Optional: 1 ACR + 1 Role Assignment

### 4. Apply the Configuration

```bash
terraform apply
```

Type `yes` to confirm. Deployment takes approximately 8-10 minutes.

### 5. Get Cluster Credentials

After successful deployment:

```bash
# Terraform outputs the command
terraform output -raw get_credentials_command | bash

# Or manually
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw cluster_name)
```

### 6. Verify Cluster

```bash
kubectl cluster-info
kubectl get nodes
```

## File Structure

```
bootstrap/terraform/
├── main.tf                      # Main configuration
├── variables.tf                 # Input variables with validation
├── outputs.tf                   # Output values
├── versions.tf                  # Provider versions
├── terraform.tfvars.example     # Example variables (copy to .tfvars)
├── terraform.tfvars             # Your values (gitignored!)
└── README.md                    # This file
```

## Configuration Details

### Resource Group (main.tf)

Creates a resource group with tags:

- `environment`: From var.environment
- `purpose`: “flux-crossplane-management”
- `owner`: From var.owner
- `managed_by`: “terraform”

### Log Analytics Workspace

For AKS monitoring:

- SKU: PerGB2018
- Retention: 30 days
- Integrated with AKS OMS agent

### AKS Cluster

**Default Node Pool**:

- Name: “system”
- VM Size: var.node_size (default: Standard_D2s_v3)
- Count: var.node_count (default: 2)
- Autoscaling: Enabled by default (2-5 nodes)
- OS Disk: 100 GB managed disk

**Network Configuration**:

- Plugin: Azure CNI
- Policy: Calico
- Service CIDR: 10.0.0.0/16
- DNS Service IP: 10.0.0.10

**Identity**:

- System-assigned managed identity
- OIDC issuer enabled (for Crossplane)
- Workload identity enabled

**Security**:

- Azure AD RBAC integration
- Network policies via Calico

**Monitoring**:

- OMS agent enabled
- Logs to Log Analytics workspace

**Maintenance**:

- Automatic patch upgrades
- Maintenance window: Sundays 2-4 AM

## Variables

### Required Variables

|Variable         |Description          |Example     |
|-----------------|---------------------|------------|
|`subscription_id`|Azure subscription ID|“12345678-…”|

### Optional Variables (with defaults)

|Variable             |Default               |Description           |
|---------------------|----------------------|----------------------|
|`resource_group_name`|“rg-flux-aks-learning”|Resource group name   |
|`location`           |“westeurope”          |Azure region          |
|`cluster_name`       |“aks-management”      |AKS cluster name      |
|`kubernetes_version` |“1.28”                |K8s version           |
|`node_count`         |2                     |Initial node count    |
|`node_size`          |“Standard_D2s_v3”     |VM size               |
|`enable_auto_scaling`|true                  |Enable autoscaler     |
|`min_node_count`     |2                     |Min nodes (autoscaler)|
|`max_node_count`     |5                     |Max nodes (autoscaler)|
|`environment`        |“learning”            |Environment tag       |
|`owner`              |“willem”              |Owner tag             |
|`create_acr`         |false                 |Create ACR            |
|`acr_name`           |“acrfluxlearning”     |ACR name (if created) |

See `variables.tf` for complete documentation and validation rules.

## Outputs

After successful deployment, Terraform provides these outputs:

### Essential Outputs

```bash
# Get specific output
terraform output resource_group_name
terraform output cluster_name
terraform output oidc_issuer_url

# Get credentials command
terraform output -raw get_credentials_command

# See all outputs
terraform output
```

### Available Outputs

|Output                      |Description                  |
|----------------------------|-----------------------------|
|`resource_group_name`       |Resource group name          |
|`cluster_name`              |AKS cluster name             |
|`cluster_id`                |AKS cluster resource ID      |
|`oidc_issuer_url`           |OIDC issuer (for Crossplane) |
|`principal_id`              |Managed identity principal ID|
|`kubelet_identity_object_id`|Kubelet identity object ID   |
|`get_credentials_command`   |Command to get kubeconfig    |
|`next_steps`                |Formatted next steps guide   |

## Remote State (Optional)

For team collaboration, configure remote state storage:

### 1. Create Storage Account

```bash
# Create resource group for state
az group create --name rg-terraform-state --location westeurope

# Create storage account (must be globally unique)
az storage account create \
  --name sttfstatelearning \
  --resource-group rg-terraform-state \
  --location westeurope \
  --sku Standard_LRS

# Create container
az storage container create \
  --name tfstate \
  --account-name sttfstatelearning
```

### 2. Configure Backend

Uncomment the backend block in `main.tf`:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"
  storage_account_name = "sttfstatelearning"
  container_name       = "tfstate"
  key                  = "flux-aks-management.tfstate"
}
```

### 3. Re-initialize

```bash
terraform init -migrate-state
```

## Cost Estimation

Approximate monthly costs (westeurope):

|Resource      |Configuration         |Cost/Month  |
|--------------|----------------------|------------|
|AKS           |2x D2s_v3 nodes       |€150-180    |
|Log Analytics |30-day retention      |€10-20      |
|Networking    |Standard load balancer|€20-30      |
|ACR (optional)|Standard tier         |€5-10       |
|**Total**     |                      |**€185-230**|

Daily cost: **€6-8**

### Cost Optimization Tips

```bash
# Stop cluster when not in use
az aks stop \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw cluster_name)

# Start when needed
az aks start \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw cluster_name)

# Or destroy completely
terraform destroy
```

## Customization Examples

### Change Node Size

```hcl
# In terraform.tfvars
node_size = "Standard_D4s_v3"  # Larger nodes
```

### Disable Autoscaling

```hcl
# In terraform.tfvars
enable_auto_scaling = false
node_count          = 3
```

### Enable ACR

```hcl
# In terraform.tfvars
create_acr = true
acr_name   = "youruniqueacrname"  # Must be globally unique
```

### Add Custom Tags

```hcl
# In terraform.tfvars
tags = {
  project     = "platform-engineering"
  cost-center = "engineering"
  team        = "cloud-team"
}
```

## Maintenance

### Update Kubernetes Version

```bash
# Check available versions
az aks get-versions --location westeurope --output table

# Update terraform.tfvars
kubernetes_version = "1.29"

# Apply changes
terraform apply
```

### Scale Nodes

```bash
# Update terraform.tfvars
node_count = 3
max_node_count = 10

# Apply changes
terraform apply
```

## Troubleshooting

### Terraform Init Fails

```bash
# Clear cache
rm -rf .terraform
rm .terraform.lock.hcl

# Re-initialize
terraform init
```

### Provider Authentication Issues

```bash
# Verify Azure CLI login
az account show

# Set subscription explicitly
az account set --subscription "your-subscription-id"
```

### Validation Errors

All variables have validation rules. Check error messages:

```bash
terraform validate
```

### State Corruption

If state is corrupted:

```bash
# Backup state
cp terraform.tfstate terraform.tfstate.backup

# Try refresh
terraform refresh

# Last resort: import resources
terraform import azurerm_kubernetes_cluster.main /subscriptions/.../resourceGroups/.../providers/Microsoft.ContainerService/managedClusters/...
```

## Cleanup

### Destroy Resources

```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy everything
terraform destroy
```

This will:

1. Delete AKS cluster (~5 minutes)
1. Delete Log Analytics workspace
1. Delete resource group
1. Delete ACR (if created)

### Cleanup Terraform Files

```bash
# Remove local state and cache
rm -rf .terraform
rm .terraform.lock.hcl
rm terraform.tfstate*
```

## Security Considerations

### Sensitive Values

Never commit these files:

- `terraform.tfvars` (contains subscription ID)
- `terraform.tfstate` (contains sensitive data)
- `.terraform/` (provider binaries)

All are in `.gitignore`.

### State File Security

The state file contains:

- Kubeconfig (including certificates)
- Managed identity details
- Resource IDs

Use remote state with access controls for production.

### Service Principal Alternative

Instead of using your personal Azure CLI login:

```bash
# Create service principal
az ad sp create-for-rbac --name terraform-sp --role Contributor

# Set environment variables
export ARM_CLIENT_ID="..."
export ARM_CLIENT_SECRET="..."
export ARM_SUBSCRIPTION_ID="..."
export ARM_TENANT_ID="..."
```

## Next Steps

After successful deployment:

1. **Get Credentials**: Use output command to configure kubectl
1. **Verify Cluster**: Run `kubectl cluster-info` and `kubectl get nodes`
1. **Install Flux**: See [docs/03-install-flux.md](../../docs/03-install-flux.md)
1. **Install Crossplane**: See [docs/04-install-crossplane.md](../../docs/04-install-crossplane.md)
1. **Save OIDC Issuer**: Note the `oidc_issuer_url` output for Crossplane configuration

## Support

For issues:

- Check Terraform documentation: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- Review Azure AKS documentation: https://learn.microsoft.com/en-us/azure/aks/
- See repository troubleshooting: [docs/08-troubleshooting.md](../../docs/08-troubleshooting.md)

-----

*Terraform configuration for learning-flux-aks-crossplane repository*
