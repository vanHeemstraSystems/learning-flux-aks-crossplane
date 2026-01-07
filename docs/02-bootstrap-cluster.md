# 02 - Bootstrap Cluster

## Overview

This guide walks you through creating the management AKS cluster that will host Flux and Crossplane. This cluster will serve as your GitOps control plane for managing additional infrastructure.

## Prerequisites

Before proceeding, ensure you have completed:

- ✅ [01 - Prerequisites](./01-prerequisites.md)
- ✅ Azure CLI configured and logged in
- ✅ All required tools installed
- ✅ Environment variables set

Verify your setup:

```bash
# Check Azure login
az account show

# Verify environment variables
echo $AZURE_SUBSCRIPTION_ID
echo $RESOURCE_GROUP
echo $CLUSTER_NAME
echo $AZURE_LOCATION
```

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│         Azure Subscription                       │
│                                                  │
│  ┌────────────────────────────────────────┐    │
│  │  Resource Group                         │    │
│  │  (rg-flux-crossplane-lab)              │    │
│  │                                          │    │
│  │  ┌────────────────────────────────┐    │    │
│  │  │  Virtual Network                │    │    │
│  │  │  10.0.0.0/16                    │    │    │
│  │  │                                  │    │    │
│  │  │  ┌───────────────────────┐     │    │    │
│  │  │  │  Subnet: aks-subnet   │     │    │    │
│  │  │  │  10.0.1.0/24          │     │    │    │
│  │  │  │                        │     │    │    │
│  │  │  │  ┌──────────────┐    │     │    │    │
│  │  │  │  │ AKS Cluster  │    │     │    │    │
│  │  │  │  │ - Flux CD    │    │     │    │    │
│  │  │  │  │ - Crossplane │    │     │    │    │
│  │  │  │  │ - 3 nodes    │    │     │    │    │
│  │  │  │  └──────────────┘    │     │    │    │
│  │  │  └───────────────────────┘     │    │    │
│  │  └────────────────────────────────┘    │    │
│  └────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

## Method 1: Azure CLI (Recommended)

This is the simplest and fastest method for creating the management cluster.

### Step 1: Set Environment Variables

```bash
# Set variables (or load from .env file)
export RESOURCE_GROUP="rg-flux-crossplane-lab"
export CLUSTER_NAME="aks-management"
export AZURE_LOCATION="West Europe"
export NODE_COUNT=3
export NODE_SIZE="Standard_D2s_v3"
export KUBERNETES_VERSION="1.28.3"
```

### Step 2: Create Resource Group

```bash
# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location "$AZURE_LOCATION"

# Verify creation
az group show --name $RESOURCE_GROUP
```

### Step 3: Create AKS Cluster

```bash
# Create AKS cluster
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --location "$AZURE_LOCATION" \
  --node-count $NODE_COUNT \
  --node-vm-size $NODE_SIZE \
  --kubernetes-version $KUBERNETES_VERSION \
  --enable-managed-identity \
  --enable-addons monitoring \
  --network-plugin azure \
  --network-policy calico \
  --generate-ssh-keys \
  --yes

# This takes 5-10 minutes
echo "⏳ Creating AKS cluster... (this will take 5-10 minutes)"
```

**Note**: The `--yes` flag accepts the default SSH key generation prompt.

### Step 4: Get Cluster Credentials

```bash
# Configure kubectl to use the cluster
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --overwrite-existing

# Verify connection
kubectl cluster-info
kubectl get nodes
```

Expected output:

```
NAME                                STATUS   ROLES   AGE     VERSION
aks-nodepool1-12345678-vmss000000   Ready    agent   5m      v1.28.3
aks-nodepool1-12345678-vmss000001   Ready    agent   5m      v1.28.3
aks-nodepool1-12345678-vmss000002   Ready    agent   5m      v1.28.3
```

### Step 5: Verify Cluster Health

```bash
# Check node status
kubectl get nodes -o wide

# Check system pods
kubectl get pods --all-namespaces

# Verify DNS
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl -I https://www.google.com
```

-----

## Method 2: Using Terraform (Alternative)

For infrastructure-as-code enthusiasts, you can use Terraform.

### Step 1: Create Terraform Configuration

Create `bootstrap/terraform/main.tf`:

```hcl
terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  
  tags = {
    Environment = "Lab"
    ManagedBy   = "Terraform"
    Purpose     = "FluxCrossplaneLearning"
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "system"
    node_count          = var.node_count
    vm_size             = var.node_size
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 5
    os_disk_size_gb     = 30
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    load_balancer_sku = "standard"
    service_cidr      = "10.2.0.0/24"
    dns_service_ip    = "10.2.0.10"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }

  tags = {
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.cluster_name}-law"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
```

Create `bootstrap/terraform/variables.tf`:

```hcl
variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-flux-crossplane-lab"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "West Europe"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-management"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28.3"
}

variable "node_count" {
  description = "Number of nodes"
  type        = number
  default     = 3
}

variable "node_size" {
  description = "VM size for nodes"
  type        = string
  default     = "Standard_D2s_v3"
}
```

Create `bootstrap/terraform/outputs.tf`:

```hcl
output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "cluster_fqdn" {
  value = azurerm_kubernetes_cluster.aks.fqdn
}

output "kubeconfig_command" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}
```

Create `bootstrap/terraform/terraform.tfvars`:

```hcl
subscription_id = "your-subscription-id-here"
```

### Step 2: Deploy with Terraform

```bash
# Navigate to terraform directory
cd bootstrap/terraform

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply configuration
terraform apply

# Get kubeconfig
eval $(terraform output -raw kubeconfig_command)

# Verify
kubectl get nodes
```

-----

## Method 3: Using Automation Script

For convenience, use the provided script.

### Create Bootstrap Script

Create `bootstrap/scripts/create-aks.sh`:

```bash
#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 AKS Management Cluster Bootstrap${NC}"
echo "======================================"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI not found${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Azure CLI found${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found${NC}"
    exit 1
fi
echo -e "${GREEN}✅ kubectl found${NC}"

# Check Azure login
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not logged in to Azure${NC}"
    echo "Run: az login"
    exit 1
fi
echo -e "${GREEN}✅ Logged in to Azure${NC}"

# Set variables
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-flux-crossplane-lab}"
CLUSTER_NAME="${CLUSTER_NAME:-aks-management}"
AZURE_LOCATION="${AZURE_LOCATION:-West Europe}"
NODE_COUNT="${NODE_COUNT:-3}"
NODE_SIZE="${NODE_SIZE:-Standard_D2s_v3}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.28.3}"

echo -e "\n${YELLOW}Configuration:${NC}"
echo "Resource Group: $RESOURCE_GROUP"
echo "Cluster Name: $CLUSTER_NAME"
echo "Location: $AZURE_LOCATION"
echo "Node Count: $NODE_COUNT"
echo "Node Size: $NODE_SIZE"
echo "Kubernetes Version: $KUBERNETES_VERSION"

# Confirm
read -p "Continue with this configuration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Create resource group
echo -e "\n${YELLOW}Creating resource group...${NC}"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$AZURE_LOCATION" \
  --output table

# Create AKS cluster
echo -e "\n${YELLOW}Creating AKS cluster (this will take 5-10 minutes)...${NC}"
az aks create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --location "$AZURE_LOCATION" \
  --node-count "$NODE_COUNT" \
  --node-vm-size "$NODE_SIZE" \
  --kubernetes-version "$KUBERNETES_VERSION" \
  --enable-managed-identity \
  --enable-addons monitoring \
  --network-plugin azure \
  --network-policy calico \
  --generate-ssh-keys \
  --yes \
  --output table

# Get credentials
echo -e "\n${YELLOW}Getting cluster credentials...${NC}"
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --overwrite-existing

# Verify
echo -e "\n${YELLOW}Verifying cluster...${NC}"
kubectl cluster-info
echo ""
kubectl get nodes

# Save cluster information
echo -e "\n${YELLOW}Saving cluster information...${NC}"
cat > cluster-info.txt <<EOF
Resource Group: $RESOURCE_GROUP
Cluster Name: $CLUSTER_NAME
Location: $AZURE_LOCATION

To get credentials again:
  az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

To delete cluster:
  az group delete --name $RESOURCE_GROUP --yes --no-wait
EOF

echo -e "\n${GREEN}✅ Cluster created successfully!${NC}"
echo -e "${YELLOW}Cluster information saved to: cluster-info.txt${NC}"
echo -e "\n${GREEN}Next steps:${NC}"
echo "  1. Review docs/03-install-flux.md"
echo "  2. Bootstrap Flux on this cluster"
```

Make executable and run:

```bash
chmod +x bootstrap/scripts/create-aks.sh
./bootstrap/scripts/create-aks.sh
```

-----

## Post-Bootstrap Configuration

### Enable Additional Features

```bash
# Enable Azure RBAC (optional)
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-azure-rbac

# Enable workload identity (recommended for production)
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-oidc-issuer \
  --enable-workload-identity
```

### Configure kubectl Context

```bash
# Set current context
kubectl config use-context $CLUSTER_NAME

# View contexts
kubectl config get-contexts

# Rename context for convenience
kubectl config rename-context \
  $(kubectl config current-context) \
  management
```

### Install Kubernetes Dashboard (Optional)

```bash
# Install dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create admin user
kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard
kubectl create clusterrolebinding dashboard-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:dashboard-admin

# Get token
kubectl -n kubernetes-dashboard create token dashboard-admin

# Access dashboard
kubectl proxy
# Open: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

-----

## Verification Checklist

```bash
# ✓ Cluster is running
az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --query provisioningState -o tsv
# Should output: Succeeded

# ✓ Nodes are ready
kubectl get nodes
# All nodes should be "Ready"

# ✓ System pods are running
kubectl get pods --all-namespaces
# All pods should be "Running"

# ✓ DNS is working
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- nslookup kubernetes.default
# Should resolve successfully

# ✓ Internet access
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl -I https://www.google.com
# Should return 200 OK
```

-----

## Troubleshooting

### Issue: Cluster Creation Times Out

```bash
# Check operation status
az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --query provisioningState

# If failed, check activity log
az monitor activity-log list \
  --resource-group $RESOURCE_GROUP \
  --max-events 10

# Delete and retry
az aks delete \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --yes
```

### Issue: Insufficient Quota

```bash
# Check quota
az vm list-usage \
  --location "$AZURE_LOCATION" \
  -o table | grep Standard_D

# Request quota increase (Azure Portal)
# Navigate to: Subscriptions → Usage + quotas → Request increase
```

### Issue: kubectl Cannot Connect

```bash
# Verify credentials
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --overwrite-existing

# Check kubeconfig
kubectl config view

# Test connection
kubectl cluster-info
```

### Issue: Nodes Not Ready

```bash
# Check node status
kubectl describe node <node-name>

# Check kubelet logs (requires SSH)
az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --query agentPoolProfiles[0].vmSize
```

-----

## Cost Management

### Monitor Costs

```bash
# Check current costs
az consumption usage list \
  --start-date $(date -d '30 days ago' +%Y-%m-%d) \
  --end-date $(date +%Y-%m-%d) \
  --query "[?contains(instanceName,'$CLUSTER_NAME')].{Name:instanceName, Cost:pretaxCost}" \
  --output table
```

### Optimize Costs

```bash
# Scale down during off-hours
az aks nodepool scale \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name nodepool1 \
  --node-count 1

# Scale up when needed
az aks nodepool scale \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name nodepool1 \
  --node-count 3
```

-----

## Cleanup

When you’re done with the lab:

```bash
# Delete entire resource group (removes everything)
az group delete \
  --name $RESOURCE_GROUP \
  --yes \
  --no-wait

# Verify deletion
az group show --name $RESOURCE_GROUP
# Should show: Resource group not found
```

-----

## Next Steps

With your management cluster running, proceed to:

👉 **[03 - Install Flux](./03-install-flux.md)**

This will cover:

- Bootstrapping Flux on the cluster
- Connecting Flux to your Git repository
- Configuring GitOps workflows
- Deploying your first application

## Additional Resources

- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [AKS Best Practices](https://learn.microsoft.com/en-us/azure/aks/best-practices)
- [Azure CLI AKS Reference](https://learn.microsoft.com/en-us/cli/azure/aks)
- [Terraform AKS Module](https://registry.terraform.io/modules/Azure/aks/azurerm/latest)

-----

*Estimated time: 30-60 minutes (including cluster creation wait time)*
