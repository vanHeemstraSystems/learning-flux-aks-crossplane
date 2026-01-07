# 07 - Advanced Scenarios

## Overview

This guide covers advanced Crossplane patterns and scenarios for building production-ready infrastructure platforms on Azure.

## Prerequisites

- ✅ Completed previous guides (01-06)
- ✅ Successfully provisioned at least one AKS cluster
- ✅ Familiarity with Kubernetes concepts
- ✅ Understanding of GitOps workflows

## Topics Covered

1. [Compositions and XRDs](#compositions-and-xrds)
1. [Multi-Cluster Management](#multi-cluster-management)
1. [Advanced Networking](#advanced-networking)
1. [Security and RBAC](#security-and-rbac)
1. [Observability](#observability)
1. [Disaster Recovery](#disaster-recovery)

-----

## Compositions and XRDs

### What are Compositions?

Compositions allow you to define reusable infrastructure patterns that hide complexity from end users.

**Architecture**:

```
Developer Request (Claim)
    ↓
CompositeResourceDefinition (XRD) - API Schema
    ↓
Composition - Implementation
    ↓
Managed Resources (RG, VNet, AKS, etc.)
    ↓
Azure Cloud Resources
```

### Creating a Simple AKS Composition

#### Step 1: Define the XRD

Create `infrastructure/compositions/xrd-aks.yaml`:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: compositeclusters.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: CompositeCluster
    plural: compositeclusters
  claimNames:
    kind: ClusterClaim
    plural: clusterclaims
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                parameters:
                  type: object
                  properties:
                    location:
                      type: string
                      description: Azure region
                      default: "West Europe"
                    nodeCount:
                      type: integer
                      description: Number of nodes
                      default: 3
                    nodeSize:
                      type: string
                      description: VM size for nodes
                      default: "Standard_D2s_v3"
                    kubernetesVersion:
                      type: string
                      description: Kubernetes version
                      default: "1.28.3"
                  required:
                    - location
              required:
                - parameters
```

#### Step 2: Create the Composition

Create `infrastructure/compositions/composition-aks.yaml`:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: cluster-azure-aks
  labels:
    provider: azure
    cluster: aks
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: CompositeCluster
  
  resources:
    # Resource Group
    - name: resourcegroup
      base:
        apiVersion: azure.upbound.io/v1beta1
        kind: ResourceGroup
        spec:
          forProvider:
            location: West Europe
      patches:
        - fromFieldPath: spec.parameters.location
          toFieldPath: spec.forProvider.location
        - fromFieldPath: metadata.name
          toFieldPath: metadata.name
          transforms:
            - type: string
              string:
                fmt: "rg-%s"
    
    # Virtual Network
    - name: virtualnetwork
      base:
        apiVersion: network.azure.upbound.io/v1beta1
        kind: VirtualNetwork
        spec:
          forProvider:
            addressSpace:
              - 10.0.0.0/16
            resourceGroupNameSelector:
              matchControllerRef: true
      patches:
        - fromFieldPath: spec.parameters.location
          toFieldPath: spec.forProvider.location
        - fromFieldPath: metadata.name
          toFieldPath: metadata.name
          transforms:
            - type: string
              string:
                fmt: "vnet-%s"
    
    # Subnet
    - name: subnet
      base:
        apiVersion: network.azure.upbound.io/v1beta1
        kind: Subnet
        spec:
          forProvider:
            addressPrefixes:
              - 10.0.1.0/24
            resourceGroupNameSelector:
              matchControllerRef: true
            virtualNetworkNameSelector:
              matchControllerRef: true
      patches:
        - fromFieldPath: metadata.name
          toFieldPath: metadata.name
          transforms:
            - type: string
              string:
                fmt: "subnet-%s"
    
    # AKS Cluster
    - name: kubernetescluster
      base:
        apiVersion: containerservice.azure.upbound.io/v1beta1
        kind: KubernetesCluster
        spec:
          forProvider:
            resourceGroupNameSelector:
              matchControllerRef: true
            defaultNodePool:
              - name: system
                enableAutoScaling: true
                minCount: 1
                maxCount: 5
                vnetSubnetIdSelector:
                  matchControllerRef: true
            identity:
              - type: SystemAssigned
            networkProfile:
              - networkPlugin: azure
                networkPolicy: calico
                dnsServiceIp: 10.2.0.10
                serviceCidr: 10.2.0.0/24
          writeConnectionSecretToRef:
            namespace: crossplane-system
      patches:
        - fromFieldPath: spec.parameters.location
          toFieldPath: spec.forProvider.location
        - fromFieldPath: spec.parameters.kubernetesVersion
          toFieldPath: spec.forProvider.kubernetesVersion
        - fromFieldPath: spec.parameters.nodeCount
          toFieldPath: spec.forProvider.defaultNodePool[0].nodeCount
        - fromFieldPath: spec.parameters.nodeSize
          toFieldPath: spec.forProvider.defaultNodePool[0].vmSize
        - fromFieldPath: metadata.name
          toFieldPath: spec.forProvider.dnsPrefix
        - fromFieldPath: metadata.name
          toFieldPath: spec.writeConnectionSecretToRef.name
          transforms:
            - type: string
              string:
                fmt: "%s-kubeconfig"
      connectionDetails:
        - fromConnectionSecretKey: kubeconfig
```

#### Step 3: Create a Claim

Developers can now claim clusters using a simple manifest:

```yaml
apiVersion: platform.example.com/v1alpha1
kind: ClusterClaim
metadata:
  name: dev-cluster-001
  namespace: team-platform
spec:
  parameters:
    location: West Europe
    nodeCount: 3
    nodeSize: Standard_D2s_v3
    kubernetesVersion: "1.28.3"
  writeConnectionSecretToRef:
    name: dev-cluster-001-kubeconfig
```

-----

## Multi-Cluster Management

### Hub-Spoke Architecture

```
┌────────────────────────────────────────┐
│      Management Cluster (Hub)           │
│  ┌─────────────────────────────────┐   │
│  │  Flux + Crossplane              │   │
│  └─────────────────────────────────┘   │
└──────────┬──────────┬──────────────────┘
           │          │
    ┌──────┴───┐   ┌──┴────────┐
    │          │   │           │
    ▼          ▼   ▼           ▼
┌────────┐ ┌────────┐ ┌─────────┐
│Dev AKS │ │Staging │ │Prod AKS │
│Cluster │ │AKS     │ │Cluster  │
└────────┘ └────────┘ └─────────┘
```

### Environment-Based Clusters

Create different composition for each environment:

**Development**:

```yaml
apiVersion: platform.example.com/v1alpha1
kind: ClusterClaim
metadata:
  name: dev-cluster
spec:
  parameters:
    location: West Europe
    nodeCount: 2
    nodeSize: Standard_B2s
    environment: development
```

**Production**:

```yaml
apiVersion: platform.example.com/v1alpha1
kind: ClusterClaim
metadata:
  name: prod-cluster
spec:
  parameters:
    location: West Europe
    nodeCount: 5
    nodeSize: Standard_D4s_v3
    environment: production
    highAvailability: true
    backupEnabled: true
```

-----

## Advanced Networking

### Private AKS Cluster

```yaml
apiVersion: containerservice.azure.upbound.io/v1beta1
kind: KubernetesCluster
metadata:
  name: aks-private
spec:
  forProvider:
    location: West Europe
    resourceGroupName: rg-private-aks
    
    # Enable private cluster
    privateClusterEnabled: true
    
    # Private DNS zone
    privateDnsZoneId: /subscriptions/.../privateDnsZones/privatelink.westeurope.azmk8s.io
    
    # API server access
    apiServerAuthorizedIpRanges:
      - 10.0.0.0/8  # Only allow internal network
    
    networkProfile:
      - networkPlugin: azure
        networkPolicy: azure
        serviceCidr: 10.2.0.0/24
        dnsServiceIp: 10.2.0.10
        outboundType: userDefinedRouting
```

### Azure CNI with Custom CIDR

```yaml
networkProfile:
  - networkPlugin: azure
    networkPolicy: calico
    
    # Pod CIDR (for kubenet) or subnet (for Azure CNI)
    podCidr: 10.244.0.0/16
    
    # Service CIDR
    serviceCidr: 10.2.0.0/24
    dnsServiceIp: 10.2.0.10
    
    # Docker bridge CIDR
    dockerBridgeCidr: 172.17.0.1/16
    
    # Load balancer SKU
    loadBalancerSku: standard
```

### Network Security Groups

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: SecurityGroup
metadata:
  name: nsg-aks-subnet
spec:
  forProvider:
    location: West Europe
    resourceGroupName: rg-aks
---
apiVersion: network.azure.upbound.io/v1beta1
kind: SecurityRule
metadata:
  name: allow-https
spec:
  forProvider:
    networkSecurityGroupName: nsg-aks-subnet
    resourceGroupName: rg-aks
    priority: 100
    direction: Inbound
    access: Allow
    protocol: Tcp
    sourcePortRange: "*"
    destinationPortRange: "443"
    sourceAddressPrefix: "*"
    destinationAddressPrefix: "*"
```

-----

## Security and RBAC

### Managed Identity Integration

```yaml
apiVersion: containerservice.azure.upbound.io/v1beta1
kind: KubernetesCluster
spec:
  forProvider:
    # System-assigned identity
    identity:
      - type: SystemAssigned
    
    # Or user-assigned identity
    identity:
      - type: UserAssigned
        identityIds:
          - /subscriptions/.../Microsoft.ManagedIdentity/userAssignedIdentities/aks-identity
```

### Azure Key Vault Integration

```yaml
# Key Vault
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Vault
metadata:
  name: kv-aks-secrets
spec:
  forProvider:
    location: West Europe
    resourceGroupName: rg-aks
    skuName: standard
    tenantId: YOUR_TENANT_ID
    
    # Enable for AKS
    enabledForDeployment: true
    enabledForTemplateDeployment: true
```

### Azure RBAC for AKS

```yaml
spec:
  forProvider:
    # Enable Azure RBAC
    azureRbacEnabled: true
    
    # Disable local accounts
    localAccountDisabled: true
    
    # Azure AD integration
    azureActiveDirectoryRoleBasedAccessControl:
      - managed: true
        adminGroupObjectIds:
          - YOUR_ADMIN_GROUP_ID
```

-----

## Observability

### Enable Azure Monitor

```yaml
spec:
  forProvider:
    addonProfile:
      - omsAgent:
          - enabled: true
            logAnalyticsWorkspaceResourceId: /subscriptions/.../workspaces/aks-monitoring
        
        azurePolicy:
          - enabled: true
```

### Container Insights

```yaml
# Log Analytics Workspace
apiVersion: operationsmanagement.azure.upbound.io/v1beta1
kind: LogAnalyticsWorkspace
metadata:
  name: law-aks-monitoring
spec:
  forProvider:
    location: West Europe
    resourceGroupName: rg-monitoring
    sku: PerGB2018
    retentionInDays: 30
```

### Prometheus Integration

```yaml
# In your AKS cluster
addonProfile:
  - azureMonitorKubernetesMetrics:
      - enabled: true
```

-----

## Disaster Recovery

### Backup Strategy

```yaml
# Azure Backup for AKS (via Azure Backup extension)
apiVersion: dataprotection.azure.upbound.io/v1beta1
kind: BackupVault
metadata:
  name: bv-aks-backup
spec:
  forProvider:
    location: West Europe
    resourceGroupName: rg-backup
    datastoreType: VaultStore
    redundancy: GeoRedundant
```

### Multi-Region Deployment

```yaml
---
# Primary region cluster
apiVersion: platform.example.com/v1alpha1
kind: ClusterClaim
metadata:
  name: prod-westeurope
spec:
  parameters:
    location: West Europe
    nodeCount: 5
---
# Secondary region cluster
apiVersion: platform.example.com/v1alpha1
kind: ClusterClaim
metadata:
  name: prod-northeurope
spec:
  parameters:
    location: North Europe
    nodeCount: 5
```

### GitOps-Based Recovery

All infrastructure is defined in Git:

```bash
# Disaster recovery process
git clone https://github.com/yourorg/infrastructure.git
cd infrastructure
flux bootstrap github --owner=yourorg --repository=infrastructure
# All clusters and resources will be recreated
```

-----

## Best Practices Summary

### 1. Use Compositions for Production

✅ **Do**: Create compositions for reusable patterns  
❌ **Don’t**: Use raw managed resources in production

### 2. Implement Proper RBAC

✅ **Do**: Use Azure AD integration and Azure RBAC  
❌ **Don’t**: Use local accounts in production

### 3. Enable Monitoring

✅ **Do**: Configure Container Insights from day 1  
❌ **Don’t**: Wait until you have problems

### 4. Plan for Disaster Recovery

✅ **Do**: Store everything in Git  
✅ **Do**: Test recovery procedures  
❌ **Don’t**: Assume backups work without testing

### 5. Follow Network Security

✅ **Do**: Use private clusters for production  
✅ **Do**: Implement network policies  
❌ **Don’t**: Expose API server publicly

-----

## Next Steps

Continue learning with:

👉 **[08 - Troubleshooting](./08-troubleshooting.md)**

This covers:

- Common issues and solutions
- Debugging techniques
- Performance optimization
- Support resources

## Additional Resources

- [Crossplane Composition Guide](https://docs.crossplane.io/latest/concepts/compositions/)
- [AKS Best Practices](https://learn.microsoft.com/en-us/azure/aks/best-practices)
- [Azure Well-Architected Framework](https://learn.microsoft.com/en-us/azure/well-architected/)
- [Crossplane Patterns](https://docs.crossplane.io/knowledge-base/guides/)

-----

*This guide covers advanced patterns - adapt to your needs*
