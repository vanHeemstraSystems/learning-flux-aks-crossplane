# Network Composition

This composition provides a complete Azure networking setup with VNet, subnets, and security groups.

## What This Creates

When you create a Network using this composition, Crossplane automatically provisions:

1. **Resource Group** - Container for all network resources
1. **Virtual Network** - Configurable CIDR range
1. **Subnets**:
- Workload subnet (general purpose)
- AKS subnet (for Kubernetes)
- Database subnet (optional, with delegation)
1. **Network Security Group** - With default rules
1. **Security Rules**:
- Allow HTTPS (443)
- Allow HTTP (80)
1. **NSG Associations** - Link NSG to subnets

## Files

|File                |Purpose             |
|--------------------|--------------------|
|`definition.yaml`   |XRD (API definition)|
|`composition.yaml`  |Implementation      |
|`example-claim.yaml`|Usage example       |
|`README.md`         |This file           |

## API Overview

### Simple Interface

```yaml
apiVersion: platform.example.org/v1alpha1
kind: Network
metadata:
  name: my-network
spec:
  parameters:
    networkName: my-network
    location: West Europe
    addressSpace: 10.0.0.0/16
    environment: dev
```

### Full Configuration

```yaml
apiVersion: platform.example.org/v1alpha1
kind: Network
metadata:
  name: prod-network
spec:
  parameters:
    networkName: prod-network
    location: West Europe
    addressSpace: 10.1.0.0/16
    
    subnets:
      workload:
        enabled: true
        cidr: 10.1.1.0/24
      aks:
        enabled: true
        cidr: 10.1.10.0/24
      database:
        enabled: true
        cidr: 10.1.20.0/24
    
    enableNSG: true
    enableServiceEndpoints: true
    environment: production
```

## Subnet Types

|Subnet  |Default CIDR|Purpose          |Service Endpoints     |
|--------|------------|-----------------|----------------------|
|workload|10.0.1.0/24 |General workloads|Storage, SQL, KeyVault|
|aks     |10.0.10.0/24|AKS node pools   |None                  |
|database|10.0.20.0/24|Database servers |SQL (with delegation) |

## Installation

### 1. Install XRD and Composition

```bash
# Apply the definition
kubectl apply -f definition.yaml

# Apply the composition
kubectl apply -f composition.yaml

# Verify
kubectl get xrd xnetworks.platform.example.org
kubectl get composition network-standard
```

### 2. Create a Network

```bash
# Apply example
kubectl apply -f example-claim.yaml

# Watch creation
kubectl get networks -w

# Check status
kubectl describe network prod-network
```

### 3. Monitor Resources

```bash
# See all managed resources
kubectl get managed

# Check specific resources
kubectl get resourcegroup
kubectl get virtualnetwork
kubectl get subnet
kubectl get securitygroup
```

## Usage Examples

### Development Network (Simple)

```yaml
apiVersion: platform.example.org/v1alpha1
kind: Network
metadata:
  name: dev-network
  namespace: development
spec:
  parameters:
    networkName: dev-network
    location: West Europe
    addressSpace: 10.0.0.0/16
    environment: dev
```

### Staging Network (Standard)

```yaml
apiVersion: platform.example.org/v1alpha1
kind: Network
metadata:
  name: staging-network
  namespace: staging
spec:
  parameters:
    networkName: staging-network
    location: North Europe
    addressSpace: 10.2.0.0/16
    
    subnets:
      workload:
        enabled: true
        cidr: 10.2.1.0/24
      aks:
        enabled: true
        cidr: 10.2.10.0/24
      database:
        enabled: false
    
    enableNSG: true
    enableServiceEndpoints: true
    environment: staging
```

### Production Network (Full)

```yaml
apiVersion: platform.example.org/v1alpha1
kind: Network
metadata:
  name: prod-network
  namespace: production
spec:
  parameters:
    networkName: prod-network
    location: West Europe
    addressSpace: 10.1.0.0/16
    
    subnets:
      workload:
        enabled: true
        cidr: 10.1.1.0/24
      aks:
        enabled: true
        cidr: 10.1.10.0/24
      database:
        enabled: true
        cidr: 10.1.20.0/24
    
    enableNSG: true
    enableServiceEndpoints: true
    environment: production
```

## Getting Network Information

### From Kubernetes

```bash
# Get network status
kubectl get network prod-network -o yaml

# Extract VNet ID
kubectl get network prod-network -o jsonpath='{.status.vnetId}'

# Extract subnet IDs
kubectl get network prod-network -o jsonpath='{.status.workloadSubnetId}'
kubectl get network prod-network -o jsonpath='{.status.aksSubnetId}'
```

### From Azure

```bash
# List all resources
az network vnet show \
  --resource-group rg-network-prod-network \
  --name vnet-prod-network

# List subnets
az network vnet subnet list \
  --resource-group rg-network-prod-network \
  --vnet-name vnet-prod-network \
  --output table
```

## Customization

### Change Default Subnets

Edit `composition.yaml` to change defaults:

```yaml
# Workload subnet default
- name: workload-subnet
  base:
    spec:
      forProvider:
        addressPrefixes:
          - 10.0.2.0/24  # Change from 10.0.1.0/24
```

### Add Additional Subnets

Add new subnet resource to composition:

```yaml
- name: management-subnet
  base:
    apiVersion: network.azure.upbound.io/v1beta1
    kind: Subnet
    metadata:
      labels:
        subnet-type: management
    spec:
      forProvider:
        addressPrefixes:
          - 10.0.30.0/24
```

### Modify NSG Rules

Add or modify security rules in composition:

```yaml
- name: nsg-rule-ssh
  base:
    apiVersion: network.azure.upbound.io/v1beta1
    kind: SecurityRule
    spec:
      forProvider:
        priority: 120
        direction: Inbound
        access: Allow
        protocol: Tcp
        sourcePortRange: "*"
        destinationPortRange: "22"
        sourceAddressPrefix: "YOUR_IP/32"
        destinationAddressPrefix: "*"
```

### Enable VNet Peering

Add peering resource to composition:

```yaml
- name: vnet-peering
  base:
    apiVersion: network.azure.upbound.io/v1beta1
    kind: VirtualNetworkPeering
    spec:
      forProvider:
        allowVirtualNetworkAccess: true
        allowForwardedTraffic: true
```

## Integration with Other Resources

### Use with AKS Cluster

Reference the network in AKS composition:

```yaml
# In AKS cluster claim
spec:
  parameters:
    networkRef:
      name: prod-network
      namespace: default
```

### Use with Database

Reference database subnet:

```yaml
# In Database composition
spec:
  forProvider:
    delegatedSubnetIdSelector:
      matchLabels:
        network: prod-network
        subnet-type: database
```

### Use with Virtual Machines

Reference workload subnet:

```yaml
spec:
  forProvider:
    subnetIdSelector:
      matchLabels:
        network: prod-network
        subnet-type: workload
```

## Network Sizing Guide

### Small Network (10.0.0.0/20)

- Total IPs: 4,096
- Subnets: 3-5
- Use case: Dev/Test

### Medium Network (10.0.0.0/16)

- Total IPs: 65,536
- Subnets: 10-20
- Use case: Staging, Small Production

### Large Network (10.0.0.0/14)

- Total IPs: 262,144
- Subnets: 50+
- Use case: Enterprise Production

## Troubleshooting

### Network Not Creating

```bash
# Check composite resource
kubectl describe xnetwork

# Check managed resources
kubectl get managed | grep prod-network

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### Subnet CIDR Conflicts

```bash
# Verify CIDR doesn't overlap
az network vnet show \
  --resource-group rg-network-prod-network \
  --name vnet-prod-network \
  --query addressSpace

# Check subnet assignments
az network vnet subnet list \
  --resource-group rg-network-prod-network \
  --vnet-name vnet-prod-network \
  --query "[].{Name:name, CIDR:addressPrefix}"
```

### NSG Not Applied

```bash
# Check NSG exists
kubectl get securitygroup

# Check NSG association
kubectl get subnetnetworksecuritygroupassociation

# Verify in Azure
az network nsg show \
  --resource-group rg-network-prod-network \
  --name nsg-prod-network
```

### Service Endpoints Not Working

```bash
# Check subnet service endpoints
az network vnet subnet show \
  --resource-group rg-network-prod-network \
  --vnet-name vnet-prod-network \
  --name snet-prod-network-workload \
  --query serviceEndpoints
```

## Best Practices

### 1. Plan Address Space

Use non-overlapping CIDRs:

```
Dev:     10.0.0.0/16
Staging: 10.1.0.0/16
Prod:    10.2.0.0/16
```

### 2. Reserve Space

Leave room for growth:

```yaml
addressSpace: 10.0.0.0/16  # 65k IPs
subnets:
  workload: 10.0.1.0/24    # 256 IPs
  aks: 10.0.10.0/23        # 512 IPs (room for scaling)
  database: 10.0.20.0/24   # 256 IPs
  # 10.0.30.0-10.0.255.0 reserved for future
```

### 3. Use Descriptive Names

```yaml
networkName: prod-westeu-network  # Environment-Region-Purpose
```

### 4. Tag Everything

```yaml
environment: production
cost-center: engineering
project: platform
```

### 5. Enable Service Endpoints

For Azure services you’ll use:

```yaml
enableServiceEndpoints: true  # Storage, SQL, KeyVault
```

### 6. Secure with NSGs

Start restrictive, open as needed:

```yaml
enableNSG: true
# Add specific rules rather than allow-all
```

## Security Considerations

### Network Segmentation

Use subnets to isolate workloads:

```
Workload Subnet: Public-facing apps
AKS Subnet: Kubernetes nodes (private)
Database Subnet: Databases (private, delegated)
```

### NSG Best Practices

- Default deny all inbound
- Allow specific ports only
- Use source IP restrictions
- Log denied traffic

### Service Endpoints

Enable for Azure services:

- Microsoft.Storage (blob, file)
- Microsoft.Sql (databases)
- Microsoft.KeyVault (secrets)

### Private Endpoints

For production, consider private endpoints instead of service endpoints.

## Cost Estimates

|Resource         |Monthly Cost                           |
|-----------------|---------------------------------------|
|Virtual Network  |Free                                   |
|Subnets          |Free                                   |
|NSG              |Free                                   |
|Service Endpoints|Free                                   |
|Data Transfer    |€0.05-0.10/GB                          |
|**Total**        |**~€5-20/month** (mainly data transfer)|

## Monitoring

### Check Network Health

```bash
# Network status
kubectl get network prod-network

# Subnet usage
az network vnet subnet show \
  --resource-group rg-network-prod-network \
  --vnet-name vnet-prod-network \
  --name snet-prod-network-workload \
  --query "{Name:name, IPs:ipConfigurations[].id | length(@)}"
```

### Network Flow Logs

Enable NSG flow logs:

```yaml
# Add to composition
- name: nsg-flow-logs
  base:
    apiVersion: network.azure.upbound.io/v1beta1
    kind: NetworkWatcherFlowLog
```

## Cleanup

```bash
# Delete the claim
kubectl delete network prod-network

# Crossplane deletes all resources
# Monitor deletion
kubectl get managed -w
```

## Next Steps

1. ✅ Create network
1. ✅ Verify subnets
1. ⏳ Deploy AKS cluster using this network
1. ⏳ Deploy database using database subnet
1. ⏳ Configure VNet peering for hub-spoke

## Related Compositions

- [AKS Cluster](../aks-cluster/) - Use network for AKS
- [PostgreSQL](../postgresql/) - Use database subnet

-----

*Network Composition for learning-flux-aks-crossplane repository*
