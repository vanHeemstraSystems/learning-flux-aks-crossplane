#!/bin/bash

# Script to create Azure Service Principal for Crossplane
# This script creates a service principal with Contributor role
# and generates the credentials file needed by Crossplane

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Azure Service Principal Setup for Crossplane${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    echo "Please install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo -e "${RED}Error: Not logged in to Azure${NC}"
    echo "Please run: az login"
    exit 1
fi

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo -e "${GREEN}Current Azure Subscription:${NC}"
echo "  Name: $SUBSCRIPTION_NAME"
echo "  ID: $SUBSCRIPTION_ID"
echo "  Tenant: $TENANT_ID"
echo ""

# Confirm subscription
read -p "Continue with this subscription? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cancelled by user${NC}"
    exit 0
fi

# Service principal name
SP_NAME="${SP_NAME:-crossplane-sp}"
echo ""
echo -e "${BLUE}Creating Service Principal: ${SP_NAME}${NC}"

# Create service principal
echo "Creating service principal with Contributor role..."
SP_OUTPUT=$(az ad sp create-for-rbac \
    --name "$SP_NAME" \
    --role Contributor \
    --scopes "/subscriptions/$SUBSCRIPTION_ID" \
    --sdk-auth)

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create service principal${NC}"
    exit 1
fi

# Save credentials to file
CREDS_FILE="azure-credentials.json"
echo "$SP_OUTPUT" > "$CREDS_FILE"

echo -e "${GREEN}✓ Service principal created successfully${NC}"
echo ""

# Extract values for display
CLIENT_ID=$(echo "$SP_OUTPUT" | jq -r '.clientId')
CLIENT_SECRET=$(echo "$SP_OUTPUT" | jq -r '.clientSecret')

echo -e "${GREEN}Service Principal Details:${NC}"
echo "  Name: $SP_NAME"
echo "  Client ID: $CLIENT_ID"
echo "  Client Secret: ${CLIENT_SECRET:0:8}..." # Show only first 8 chars
echo "  Subscription: $SUBSCRIPTION_ID"
echo "  Tenant: $TENANT_ID"
echo ""
echo -e "${GREEN}✓ Credentials saved to: ${CREDS_FILE}${NC}"
echo ""

# Create Kubernetes secret
echo -e "${BLUE}Creating Kubernetes secret...${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}Warning: kubectl not found${NC}"
    echo "Please create the secret manually:"
    echo ""
    echo "kubectl create secret generic azure-credentials \\"
    echo "  -n crossplane-system \\"
    echo "  --from-file=credentials=${CREDS_FILE}"
else
    # Check if crossplane-system namespace exists
    if kubectl get namespace crossplane-system &> /dev/null; then
        # Create or update secret
        kubectl create secret generic azure-credentials \
            -n crossplane-system \
            --from-file=credentials="$CREDS_FILE" \
            --dry-run=client -o yaml | kubectl apply -f -
        
        echo -e "${GREEN}✓ Secret created/updated in crossplane-system namespace${NC}"
    else
        echo -e "${YELLOW}Warning: crossplane-system namespace not found${NC}"
        echo "Please create the secret after installing Crossplane:"
        echo ""
        echo "kubectl create secret generic azure-credentials \\"
        echo "  -n crossplane-system \\"
        echo "  --from-file=credentials=${CREDS_FILE}"
    fi
fi

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Install Crossplane if not already installed"
echo "2. Install Azure providers:"
echo "   kubectl apply -f provider-azure.yaml"
echo "3. Apply ProviderConfig:"
echo "   kubectl apply -f provider-config-azure.yaml"
echo "4. Verify providers are healthy:"
echo "   kubectl get providers"
echo ""
echo -e "${RED}⚠️  Security Reminder:${NC}"
echo "- Keep ${CREDS_FILE} secure"
echo "- Delete it after creating the Kubernetes secret"
echo "- Never commit it to version control"
echo "- Rotate credentials regularly"
echo ""
echo "To delete the credentials file:"
echo "  rm ${CREDS_FILE}"
echo ""

