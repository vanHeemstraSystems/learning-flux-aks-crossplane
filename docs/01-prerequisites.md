# 01 - Prerequisites

## Overview

This guide ensures you have all the required tools, accounts, and knowledge to successfully work with Flux, AKS, and Crossplane.

## Required Tools

### 1. Azure CLI

**Purpose**: Interact with Azure resources and manage subscriptions

**Installation**:

```bash
# macOS
brew install azure-cli

# Windows (with winget)
winget install Microsoft.AzureCLI

# Linux (Ubuntu/Debian)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

**Verification**:

```bash
az --version
# Should show version 2.50.0 or higher
```

**Configuration**:

```bash
# Login to Azure
az login

# List subscriptions
az account list --output table

# Set default subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify current subscription
az account show
```

### 2. kubectl

**Purpose**: Kubernetes command-line tool for cluster management

**Installation**:

```bash
# macOS
brew install kubectl

# Windows (with winget)
winget install Kubernetes.kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

**Verification**:

```bash
kubectl version --client
# Should show version 1.28.0 or higher
```

### 3. Flux CLI

**Purpose**: GitOps toolkit for Kubernetes

**Installation**:

```bash
# macOS
brew install fluxcd/tap/flux

# Windows (with winget)
winget install FluxCD.Flux

# Linux
curl -s https://fluxcd.io/install.sh | sudo bash
```

**Verification**:

```bash
flux --version
# Should show version 2.2.0 or higher

# Check prerequisites
flux check --pre
```

### 4. Git

**Purpose**: Version control for GitOps workflows

**Installation**:

```bash
# macOS
brew install git

# Windows (with winget)
winget install Git.Git

# Linux (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install git
```

**Verification**:

```bash
git --version
# Should show version 2.30.0 or higher
```

**Configuration**:

```bash
# Set your identity
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Verify
git config --list
```

### 5. jq (JSON processor)

**Purpose**: Parse JSON responses from Azure CLI and kubectl

**Installation**:

```bash
# macOS
brew install jq

# Windows (with winget)
winget install jqlang.jq

# Linux
sudo apt-get install jq
```

**Verification**:

```bash
jq --version
# Should show version 1.6 or higher
```

### 6. Crossplane CLI (Optional but Recommended)

**Purpose**: Crossplane command-line tool for debugging and package management

**Installation**:

```bash
# macOS
brew install crossplane-contrib/tap/crossplane-cli

# Linux/WSL
curl -sL https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh | sh
sudo mv kubectl-crossplane /usr/local/bin

# Windows (manual download)
# Download from: https://github.com/crossplane/crossplane/releases
# Add to PATH
```

**Verification**:

```bash
kubectl crossplane --version
```

## Required Accounts and Access

### Azure Subscription

**Requirements**:

- Active Azure subscription
- Contributor role or higher
- Sufficient quota for:
  - Virtual Machines (D-series)
  - Virtual Networks
  - Public IP addresses
  - Load Balancers

**Verification**:

```bash
# Check subscription
az account show

# Check role assignments
az role assignment list --assignee $(az account show --query user.name -o tsv)

# Check VM quota
az vm list-usage --location "West Europe" -o table | grep Standard_D
```

**Cost Warning**: Running this learning environment will incur costs. See the [cost estimation section](#cost-estimation) below.

### GitHub Account

**Requirements**:

- GitHub account (free tier is sufficient)
- Personal Access Token with permissions:
  - `repo` (all)
  - `workflow`
  - `admin:repo_hook` (read/write)

**Creating a Personal Access Token**:

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
1. Click “Generate new token (classic)”
1. Give it a descriptive name (e.g., “Flux GitOps Lab”)
1. Select scopes:
- ✅ `repo` (all sub-scopes)
- ✅ `workflow`
- ✅ `admin:repo_hook` (read and write)
1. Click “Generate token”
1. **Copy the token immediately** (you won’t see it again)
1. Store it securely (password manager recommended)

**Setting up the token**:

```bash
# Export token for Flux bootstrap
export GITHUB_TOKEN="ghp_your_token_here"
export GITHUB_USER="your-github-username"

# Verify
echo $GITHUB_TOKEN | cut -c1-10  # Should show: ghp_xxxxx
echo $GITHUB_USER
```

## Required Knowledge

### Basic Understanding Required

**Kubernetes Concepts**:

- ✅ Pods, Deployments, Services
- ✅ Namespaces
- ✅ ConfigMaps and Secrets
- ✅ YAML manifest structure
- ✅ kubectl basic commands

**Git and Version Control**:

- ✅ Git clone, commit, push, pull
- ✅ Branches and pull requests
- ✅ Merge conflicts resolution
- ✅ `.gitignore` usage

**Azure Basics**:

- ✅ Resource Groups
- ✅ Virtual Networks and Subnets
- ✅ Azure Kubernetes Service (AKS)
- ✅ Azure Portal navigation

**Command Line**:

- ✅ Bash/PowerShell basics
- ✅ Environment variables
- ✅ File system navigation
- ✅ Text editing (vi/vim/nano or VS Code)

### Helpful But Not Required

- Docker and container concepts
- Helm package manager
- Infrastructure as Code (Terraform)
- YAML templating with Kustomize
- GitOps principles

## Workspace Setup

### Directory Structure

Create a workspace directory:

```bash
# Create workspace
mkdir -p ~/workspace/learning-flux-aks-crossplane
cd ~/workspace/learning-flux-aks-crossplane

# Clone your repository (after Flux bootstrap)
git clone https://github.com/$GITHUB_USER/learning-flux-aks-crossplane.git
cd learning-flux-aks-crossplane
```

### Environment Variables

Create a `.env` file for convenience:

```bash
cat > ~/.flux-aks-crossplane.env <<EOF
# Azure Configuration
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_LOCATION="West Europe"
export RESOURCE_GROUP="rg-flux-crossplane-lab"
export CLUSTER_NAME="aks-management"

# GitHub Configuration
export GITHUB_TOKEN="your-github-token"
export GITHUB_USER="your-github-username"
export GITHUB_REPO="learning-flux-aks-crossplane"

# Kubeconfig
export KUBECONFIG=~/.kube/config
EOF

# Load environment variables
source ~/.flux-aks-crossplane.env

# Add to your shell profile for persistence
echo "source ~/.flux-aks-crossplane.env" >> ~/.bashrc  # or ~/.zshrc
```

### Text Editor

Choose and configure a text editor:

**VS Code (Recommended)**:

```bash
# macOS
brew install --cask visual-studio-code

# Windows
winget install Microsoft.VisualStudioCode

# Install useful extensions
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
code --install-extension ms-azuretools.vscode-azureterraform
code --install-extension redhat.vscode-yaml
code --install-extension github.vscode-pull-request-github
```

**Vim/Neovim**:

```bash
# macOS
brew install neovim

# Linux
sudo apt-get install neovim

# Add to ~/.config/nvim/init.vim
set tabstop=2
set shiftwidth=2
set expandtab
syntax on
```

## Network Requirements

### Firewall and Proxy

If you’re behind a corporate firewall:

```bash
# Configure HTTP proxy
export HTTP_PROXY="http://proxy.example.com:8080"
export HTTPS_PROXY="http://proxy.example.com:8080"
export NO_PROXY="localhost,127.0.0.1,.local"

# Configure Azure CLI proxy
az configure --defaults proxy=http://proxy.example.com:8080

# Configure Git proxy
git config --global http.proxy http://proxy.example.com:8080
git config --global https.proxy http://proxy.example.com:8080
```

### Required Outbound Connectivity

Ensure access to:

- ✅ `github.com` (Git repository)
- ✅ `ghcr.io` (GitHub Container Registry)
- ✅ `*.microsoft.com` (Azure services)
- ✅ `*.azure.com` (Azure services)
- ✅ `management.azure.com` (Azure Resource Manager)
- ✅ `login.microsoftonline.com` (Azure AD)
- ✅ `charts.crossplane.io` (Crossplane Helm charts)
- ✅ `xpkg.upbound.io` (Crossplane providers)
- ✅ `fluxcd.io` (Flux documentation and binaries)

**Test connectivity**:

```bash
# Test Azure
curl -I https://management.azure.com

# Test GitHub
curl -I https://github.com

# Test Crossplane
curl -I https://charts.crossplane.io

# Test Flux
curl -I https://fluxcd.io
```

## Cost Estimation

### Estimated Monthly Costs (West Europe)

**Management Cluster**:

- AKS Control Plane: Free (for single cluster)
- 3x Standard_D2s_v3 nodes: ~€210/month
- Load Balancer: ~€20/month
- Virtual Network: ~€5/month
- **Subtotal**: ~€235/month

**Workload Cluster** (when provisioned):

- AKS Control Plane: Free
- 3x Standard_D2s_v3 nodes: ~€210/month
- Load Balancer: ~€20/month
- **Subtotal**: ~€230/month

**Total Estimated Cost**: ~€465/month for both clusters

### Cost Optimization Tips

```bash
# Use smaller VMs for learning
# Standard_B2s: ~€30/month per node (instead of Standard_D2s_v3)

# Enable auto-scaling with lower minimums
# Start with 1 node, scale to 3 when needed

# Delete resources when not in use
az group delete --name $RESOURCE_GROUP --yes --no-wait

# Use Azure Dev/Test subscriptions if available
# 20-50% discount on compute costs
```

## Verification Checklist

Run this complete verification script:

```bash
#!/bin/bash
echo "🔍 Verifying Prerequisites..."

# Check Azure CLI
if command -v az &> /dev/null; then
    echo "✅ Azure CLI: $(az --version | head -n1)"
else
    echo "❌ Azure CLI not found"
fi

# Check kubectl
if command -v kubectl &> /dev/null; then
    echo "✅ kubectl: $(kubectl version --client --short 2>/dev/null)"
else
    echo "❌ kubectl not found"
fi

# Check Flux
if command -v flux &> /dev/null; then
    echo "✅ Flux: $(flux --version)"
else
    echo "❌ Flux not found"
fi

# Check Git
if command -v git &> /dev/null; then
    echo "✅ Git: $(git --version)"
else
    echo "❌ Git not found"
fi

# Check jq
if command -v jq &> /dev/null; then
    echo "✅ jq: $(jq --version)"
else
    echo "❌ jq not found"
fi

# Check Azure login
if az account show &> /dev/null; then
    echo "✅ Azure: Logged in as $(az account show --query user.name -o tsv)"
else
    echo "❌ Azure: Not logged in"
fi

# Check environment variables
if [ -n "$GITHUB_TOKEN" ]; then
    echo "✅ GitHub Token: Set"
else
    echo "❌ GitHub Token: Not set"
fi

if [ -n "$GITHUB_USER" ]; then
    echo "✅ GitHub User: $GITHUB_USER"
else
    echo "❌ GitHub User: Not set"
fi

echo ""
echo "🎉 Verification complete!"
```

Save as `verify-prerequisites.sh`, make executable, and run:

```bash
chmod +x verify-prerequisites.sh
./verify-prerequisites.sh
```

## Troubleshooting

### Issue: Azure CLI not found after installation

```bash
# macOS - reload shell
source ~/.bashrc  # or ~/.zshrc

# Windows - restart terminal or run
refreshenv

# Linux - check PATH
echo $PATH | grep azure-cli
```

### Issue: kubectl cannot connect to Docker Desktop

```bash
# Verify Docker Desktop Kubernetes is enabled
# Settings → Kubernetes → Enable Kubernetes

# Reset Kubernetes cluster if needed
# Settings → Kubernetes → Reset Kubernetes Cluster
```

### Issue: Flux check fails

```bash
# Check prerequisites
flux check --pre

# Common issue: kubectl not configured
kubectl cluster-info

# If no cluster: you'll configure this in the next guide
```

### Issue: GitHub token permissions

```bash
# Test token
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# If error: regenerate token with correct scopes
# See "Creating a Personal Access Token" section above
```

## Next Steps

Once all prerequisites are met, proceed to:

👉 **[02 - Bootstrap Cluster](./02-bootstrap-cluster.md)**

This will cover:

- Creating the management AKS cluster
- Configuring kubectl access
- Verifying cluster health
- Preparing for Flux installation

## Additional Resources

- [Azure CLI Documentation](https://learn.microsoft.com/en-us/cli/azure/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Flux Documentation](https://fluxcd.io/docs/)
- [Git Basics](https://git-scm.com/book/en/v2/Getting-Started-Git-Basics)

## Quick Reference

### Essential Commands

```bash
# Azure
az login
az account show
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

# kubectl
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces

# Flux
flux check
flux get sources git
flux get kustomizations

# Git
git status
git add .
git commit -m "message"
git push
```

### Useful Aliases

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kgd='kubectl get deployments'
alias fget='flux get all'
alias fcheck='flux check'
```

-----

*Estimated time to complete: 1-2 hours*
