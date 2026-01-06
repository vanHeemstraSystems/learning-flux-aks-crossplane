# Learning Flux AKS Crossplane

A comprehensive learning repository demonstrating how to provision Azure Kubernetes Service (AKS) clusters using Infrastructure as Code with GitOps principles via Flux CD and Crossplane.

## Overview

This repository teaches you how to:

- Bootstrap an AKS cluster using Terraform or Azure CLI
- Install and configure Flux CD for GitOps workflows
- Deploy Crossplane to manage Azure infrastructure
- Use Crossplane to provision additional Azure resources (AKS clusters, databases, networking)
- Implement GitOps best practices for infrastructure management

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub Repository                        │
│  (Infrastructure as Code + Kubernetes Manifests)            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Flux CD watches repository
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                    Management AKS Cluster                    │
│  ┌────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │  Flux CD   │  │  Crossplane  │  │  Azure Provider  │   │
│  │  Operator  │→ │  Core        │→ │  (provider-azure)│   │
│  └────────────┘  └──────────────┘  └──────────────────┘   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Crossplane provisions Azure resources
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                      Azure Resources                         │
│  ┌──────────┐  ┌──────────┐  ┌────────────┐  ┌──────────┐ │
│  │   AKS    │  │   VNet   │  │  Databases │  │  Storage │ │
│  │ Clusters │  │          │  │            │  │          │ │
│  └──────────┘  └──────────┘  └────────────┘  └──────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Required Tools

- **Azure CLI** (v2.50+): `az --version`
- **kubectl** (v1.28+): `kubectl version --client`
- **Flux CLI** (v2.2+): `flux --version`
- **Terraform** (v1.6+) - Optional: `terraform --version`
- **Git**: `git --version`

### Required Access

- Azure subscription with Contributor role
- GitHub account with repository access
- Azure service principal or managed identity for Crossplane

### Knowledge Prerequisites

- Basic Kubernetes concepts (pods, deployments, services)
- Understanding of GitOps principles
- Familiarity with Azure services (AKS, networking, identity)
- YAML manifest syntax

## Repository Structure

```
learning-flux-aks-crossplane/
├── README.md                          # This file
├── docs/
│   ├── 01-prerequisites.md           # Detailed prerequisites and setup
│   ├── 02-bootstrap-cluster.md       # Creating the management cluster
│   ├── 03-install-flux.md            # Installing and configuring Flux
│   ├── 04-install-crossplane.md      # Installing Crossplane
│   ├── 05-configure-azure-provider.md # Azure provider setup
│   ├── 06-provision-aks.md           # Provisioning AKS with Crossplane
│   ├── 07-advanced-scenarios.md      # Advanced use cases
│   └── 08-troubleshooting.md         # Common issues and solutions
├── bootstrap/
│   ├── terraform/                     # Terraform for initial AKS
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── scripts/                       # Alternative Azure CLI scripts
│       └── create-aks.sh
├── clusters/
│   └── management/                    # Management cluster config
│       ├── flux-system/              # Flux system components
│       ├── crossplane-system/        # Crossplane installation
│       └── infrastructure/           # Infrastructure definitions
├── crossplane/
│   ├── providers/                     # Crossplane provider configs
│   │   ├── provider-azure.yaml
│   │   └── provider-config.yaml
│   ├── compositions/                  # Reusable infrastructure patterns
│   │   ├── aks-cluster/
│   │   ├── postgresql/
│   │   └── networking/
│   └── claims/                        # Infrastructure requests
│       └── examples/
├── examples/
│   ├── simple-aks/                   # Simple AKS cluster
│   ├── aks-with-addons/              # AKS with monitoring, policies
│   └── multi-cluster/                # Multiple environment setup
└── .github/
    └── workflows/                     # CI/CD pipelines
        └── validate.yaml
```

## Quick Start

### Step 1: Clone Repository

```bash
git clone https://github.com/vanHeemstraSystems/learning-flux-aks-crossplane.git
cd learning-flux-aks-crossplane
```

### Step 2: Set Environment Variables

```bash
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export RESOURCE_GROUP="rg-flux-aks-learning"
export CLUSTER_NAME="aks-management"
export LOCATION="westeurope"
export GITHUB_USER="vanHeemstraSystems"
export GITHUB_REPO="learning-flux-aks-crossplane"
```

### Step 3: Create Management Cluster

```bash
# Using Azure CLI (fastest)
./bootstrap/scripts/create-aks.sh

# OR using Terraform
cd bootstrap/terraform
terraform init
terraform apply
```

### Step 4: Install Flux

```bash
# Export GitHub token
export GITHUB_TOKEN="your-github-token"

# Bootstrap Flux
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=./clusters/management \
  --personal
```

### Step 5: Verify Installation

```bash
# Check Flux components
flux check

# Watch Flux reconciliation
flux get kustomizations --watch

# Check Crossplane installation (after Flux deploys it)
kubectl get pods -n crossplane-system
```

## Learning Path

### Module 1: Foundation (Days 1-2)

- Understand GitOps principles and Flux architecture
- Create management AKS cluster
- Install and configure Flux CD
- **Goal**: Have a GitOps-managed cluster

### Module 2: Crossplane Basics (Days 3-4)

- Install Crossplane core
- Configure Azure provider
- Create your first Crossplane resource
- **Goal**: Provision a simple Azure resource via Crossplane

### Module 3: AKS Provisioning (Days 5-7)

- Design AKS compositions
- Create AKS cluster using Crossplane
- Implement networking and security
- **Goal**: Provision a production-ready AKS cluster

### Module 4: Advanced Patterns (Days 8-10)

- Multi-cluster management
- Composite resources and compositions
- GitOps workflow optimization
- **Goal**: Build reusable infrastructure templates

## Key Concepts

### GitOps with Flux

Flux continuously reconciles the desired state in Git with the actual state in your cluster. Benefits include:

- **Single source of truth**: Git repository is the authoritative configuration source
- **Automated synchronization**: Changes in Git automatically deploy to clusters
- **Audit trail**: Git history provides complete change tracking
- **Security**: Pull-based model, no external access to clusters needed

### Crossplane as Control Plane

Crossplane extends Kubernetes to manage cloud infrastructure:

- **Kubernetes-native**: Use kubectl to manage infrastructure
- **Declarative**: Define desired state, Crossplane handles implementation
- **Composable**: Build reusable infrastructure abstractions
- **Provider-agnostic**: Single API for multi-cloud resources

### The Management Cluster Pattern

A dedicated management cluster runs Flux and Crossplane to provision and manage workload clusters:

- **Separation of concerns**: Infrastructure management isolated from workloads
- **Centralized control**: Single point for multi-cluster operations
- **Cost-effective**: Small management cluster, scale workload clusters as needed
- **Resilient**: Management cluster remains stable while workload clusters scale

## Real-World Use Cases

### Use Case 1: Development Environment Provisioning

Developers can request complete environments (AKS + database + networking) by creating a simple YAML claim. Crossplane provisions everything automatically.

### Use Case 2: Multi-Tenant SaaS Platform

Each customer gets an isolated AKS cluster with consistent configuration through compositions. Flux ensures all clusters stay updated.

### Use Case 3: Disaster Recovery

Infrastructure definitions in Git enable rapid cluster recreation. Crossplane rebuilds Azure resources, Flux restores applications.

## Success Criteria

By completing this learning repository, you will be able to:

- ✅ Explain GitOps principles and Flux architecture
- ✅ Bootstrap Flux on an AKS cluster
- ✅ Install and configure Crossplane with Azure provider
- ✅ Create Crossplane compositions for reusable infrastructure patterns
- ✅ Provision AKS clusters declaratively via Crossplane
- ✅ Implement a complete GitOps workflow for infrastructure
- ✅ Troubleshoot common Flux and Crossplane issues
- ✅ Apply these patterns to an Internal Developer Platform project

## Relation to Your Work at Team Rockstars Cloud

This learning repository directly supports:

- **Crossplane integration**: Hands-on experience with Crossplane + Azure
- **AKS expertise**: Deep understanding of AKS provisioning and management
- **GitOps practices**: Production-ready patterns for platform engineering
- **Azure networking**: Integration with AZ-700 certification studies

## Next Steps

1. Read through <docs/01-prerequisites.md>
1. Follow the step-by-step guides in sequence
1. Experiment with the examples in the `examples/` directory
1. Adapt patterns for your specific use cases

## Troubleshooting

See <docs/08-troubleshooting.md> for common issues and solutions.

Quick checks:

```bash
# Flux status
flux get all -A

# Crossplane status
kubectl get managed -A

# Recent events
kubectl get events -A --sort-by='.lastTimestamp'
```

## Resources

### Official Documentation

- [Flux Documentation](https://fluxcd.io/docs/)
- [Crossplane Documentation](https://docs.crossplane.io/)
- [Azure Provider for Crossplane](https://marketplace.upbound.io/providers/upbound/provider-azure/)
- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)

### Related Learning Repositories

- [learning-kubernetes](https://github.com/vanHeemstraSystems/learning-kubernetes)
- [learning-docker](https://github.com/vanHeemstraSystems/learning-docker)
- [learning-terraform](https://github.com/vanHeemstraSystems/learning-terraform)

## Contributing

This is a personal learning repository, but suggestions and improvements are welcome! Feel free to open issues or submit pull requests.

## Author

**Willem van Heemstra**
Focus: Azure, Kubernetes, GitOps, Security

-----

*Last Updated: January 2026*  
*Part of the systematic learning approach to cloud engineering and platform development*
