#!/bin/bash
# Bootstrap script to create management AKS cluster using Azure CLI
# This creates the initial cluster that will run Flux and Crossplane

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Configuration with defaults
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-flux-aks-learning}"
CLUSTER_NAME="${CLUSTER_NAME:-aks-management}"
LOCATION="${LOCATION:-westeurope}"
NODE_COUNT="${NODE_COUNT:-2}"
NODE_SIZE="${NODE_SIZE:-Standard_D2s_v3}"
K8S_VERSION="${K8S_VERSION:-1.28}"

# Display configuration
echo ""
print_info "🚀 Creating Management AKS Cluster"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Resource Group:  $RESOURCE_GROUP"
echo "Cluster Name:    $CLUSTER_NAME"
echo "Location:        $LOCATION"
echo "Node Count:      $NODE_COUNT"
echo "Node Size:       $NODE_SIZE"
echo "K8s Version:     $K8S_VERSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check prerequisites
print_info "Checking prerequisites..."

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    exit 1
fi
print_success "Azure CLI found: $(az version --query '"azure-cli"' -o tsv)"

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Run 'az login' first."
    exit 1
fi
print_success "Logged in to Azure as $(az account show --query user.name -o tsv)"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_warning "kubectl not found. You'll need it to access the cluster later."
else
    print_success "kubectl found"
fi

# Confirm before proceeding
echo ""
read -p "Continue with cluster creation? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Cluster creation cancelled."
    exit 0
fi

# Create resource group
print_info "Creating resource group..."
if az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --tags environment=learning purpose=flux-crossplane owner=willem \
  --output none; then
    print_success "Resource group created: $RESOURCE_GROUP"
else
    print_error "Failed to create resource group"
    exit 1
fi

# Create AKS cluster
print_info "Creating AKS cluster (this takes 8-10 minutes)..."
print_warning "Go grab a coffee ☕ - this will take a while..."

START_TIME=$(date +%s)

if az aks create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --location "$LOCATION" \
  --kubernetes-version "$K8S_VERSION" \
  --node-count "$NODE_COUNT" \
  --node-vm-size "$NODE_SIZE" \
  --network-plugin azure \
  --network-policy calico \
  --enable-managed-identity \
  --enable-addons monitoring \
  --generate-ssh-keys \
  --tags environment=learning purpose=management \
  --output none; then
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    print_success "AKS cluster created in ${DURATION} seconds!"
else
    print_error "Failed to create AKS cluster"
    exit 1
fi

# Get cluster credentials
print_info "Getting cluster credentials..."
if az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --overwrite-existing \
  --output none; then
    print_success "Credentials configured"
else
    print_error "Failed to get credentials"
    exit 1
fi

# Verify cluster connection
print_info "Verifying cluster connection..."
if kubectl cluster-info &> /dev/null; then
    print_success "Successfully connected to cluster"
else
    print_error "Cannot connect to cluster"
    exit 1
fi

# Display cluster info
echo ""
print_success "🎉 Management cluster is ready!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Cluster Information:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl cluster-info
echo ""
echo "Nodes:"
kubectl get nodes
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get OIDC issuer (needed for Crossplane workload identity)
print_info "Retrieving OIDC issuer URL..."
OIDC_ISSUER=$(az aks show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --query "oidcIssuerProfile.issuerUrl" -o tsv 2>/dev/null || echo "Not available")

# Save cluster information
cat > cluster-info.txt <<EOF
Management Cluster Information
===============================
Created: $(date)

Cluster Details:
  Name: $CLUSTER_NAME
  Resource Group: $RESOURCE_GROUP
  Location: $LOCATION
  Kubernetes Version: $K8S_VERSION
  Node Count: $NODE_COUNT
  Node Size: $NODE_SIZE

Azure Details:
  Subscription: $(az account show --query name -o tsv)
  OIDC Issuer: $OIDC_ISSUER

Next Steps:
  1. Install Flux: docs/03-install-flux.md
  2. Install Crossplane: docs/04-install-crossplane.md
  3. Configure Azure Provider: docs/05-configure-azure-provider.md

Useful Commands:
  # Get credentials again
  az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

  # View cluster in portal
  az aks browse --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

  # Stop cluster (save costs)
  az aks stop --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

  # Start cluster
  az aks start --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

  # Delete cluster
  az aks delete --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --yes

  # Delete resource group (removes everything)
  az group delete --name $RESOURCE_GROUP --yes
EOF

print_success "Cluster information saved to cluster-info.txt"

# Display next steps
echo ""
print_info "📚 Next Steps:"
echo "1. Review cluster-info.txt for important details"
echo "2. Install Flux CD: flux bootstrap github ..."
echo "3. See docs/03-install-flux.md for detailed instructions"
echo ""
print_warning "💰 Cost Reminder: This cluster costs ~€5-7/day"
print_warning "Stop it when not in use: az aks stop --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME"
echo ""

