# Crossplane Compositions

This directory contains reusable infrastructure patterns built as Crossplane Compositions.

## What Are Compositions?

**Compositions** are templates that define how to build complex infrastructure from simple user requests.

### The Pattern

```
User requests → Simple API (XRD) → Composition → Multiple cloud resources
```

### Example

**User creates** (simple):

```yaml
apiVersion: platform.example.org/v1alpha1
kind: AKSCluster
metadata:
  name: my-cluster
spec:
  parameters:
    size: medium
```

**Crossplane creates** (complex):

- Resource Group
- Virtual Network
- Subnet
- AKS Cluster
- Network Security Group
- Monitoring
- etc.

## Benefits Over Direct Resources

|Aspect           |Direct Resources        |Compositions                 |
|-----------------|------------------------|-----------------------------|
|Complexity       |User handles all details|Platform team handles details|
|Consistency      |Varies per user         |Enforced by composition      |
|Maintenance      |Change every instance   |Change composition once      |
|Expertise needed |Cloud provider knowledge|Business requirements only   |
|Time to provision|Configure 10+ resources |Configure 1 simple request   |

## Available Compositions

### 1. AKS Cluster (`aks-cluster/`)

**Purpose**: Provision complete AKS clusters with networking

**API**:

```yaml
apiVersion: platform.example.org/v1alpha1
kind: AKSCluster
spec:
  parameters:
    size: small | medium | large
    location: West Europe
    kubernetesVersion: "1.28"
```

**Creates**:

- Resource Group
- Virtual Network
- Subnet
- AKS Cluster

**Status**: ✅ Ready to use

See <aks-cluster/README.md>

### 2. PostgreSQL Database (Future)

**Purpose**: Managed PostgreSQL with backups and networking

**API**:

```yaml
apiVersion: platform.example.org/v1alpha1
kind: Database
spec:
  parameters:
    size: small | medium | large
    version: "14"
```

**Status**: 📝 To be created

### 3. Development Environment (Future)

**Purpose**: Complete environment (AKS + DB + Storage + Monitoring)

**API**:

```yaml
apiVersion: platform.example.org/v1alpha1
kind: DevEnvironment
spec:
  parameters:
    team: backend-team
    size: medium
```

**Status**: 📝 To be created

## Directory Structure

```
crossplane/compositions/
├── README.md                    # This file
├── aks-cluster/                 # AKS cluster composition
│   ├── definition.yaml         # XRD (API definition)
│   ├── composition.yaml        # Implementation
│   ├── example-claim.yaml      # Usage example
│   └── README.md               # Documentation
├── postgresql/                  # Future
└── dev-environment/             # Future
```

## How Compositions Work

### 1. Define the API (XRD)

Create a Custom Resource Definition:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xaksclusters.platform.example.org
spec:
  group: platform.example.org
  names:
    kind: XAKSCluster
  claimNames:
    kind: AKSCluster    # What users create
```

### 2. Implement the Pattern (Composition)

Define how to build it:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: aks-cluster-standard
spec:
  compositeTypeRef:
    apiVersion: platform.example.org/v1alpha1
    kind: XAKSCluster
  resources:
    - name: resourcegroup
      base:
        apiVersion: azure.upbound.io/v1beta1
        kind: ResourceGroup
    - name: akscluster
      base:
        apiVersion: containerservice.azure.upbound.io/v1beta1
        kind: KubernetesCluster
```

### 3. Users Create Claims

Simple requests:

```yaml
apiVersion: platform.example.org/v1alpha1
kind: AKSCluster
metadata:
  name: my-cluster
spec:
  parameters:
    size: medium
```

## Installation

### 1. Install Compositions

```bash
# Install AKS composition
kubectl apply -f aks-cluster/definition.yaml
kubectl apply -f aks-cluster/composition.yaml

# Verify
kubectl get xrd
kubectl get composition
```

### 2. Create Claims

```bash
# Use the composition
kubectl apply -f aks-cluster/example-claim.yaml

# Watch creation
kubectl get akscluster -w
```

## Creating Your Own Compositions

### Step 1: Design the API

What do users need to specify?

```yaml
# Simple example
spec:
  parameters:
    size: medium
    location: West Europe

# More complex
spec:
  parameters:
    compute:
      nodeCount: 3
      vmSize: Standard_D4s_v3
    networking:
      vnetCidr: 10.0.0.0/16
    security:
      enablePrivateCluster: true
```

### Step 2: Create XRD

```bash
mkdir crossplane/compositions/my-composition
cat > crossplane/compositions/my-composition/definition.yaml <<EOF
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xmyresources.platform.example.org
spec:
  group: platform.example.org
  names:
    kind: XMyResource
    plural: xmyresources
  claimNames:
    kind: MyResource
    plural: myresources
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
                  # Define your parameters here
EOF
```

### Step 3: Create Composition

```bash
cat > crossplane/compositions/my-composition/composition.yaml <<EOF
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: my-composition
spec:
  compositeTypeRef:
    apiVersion: platform.example.org/v1alpha1
    kind: XMyResource
  resources:
    # Define resources to create
    - name: resource1
      base:
        apiVersion: provider.upbound.io/v1beta1
        kind: SomeResource
      patches:
        # Map user input to resource fields
EOF
```

### Step 4: Test

```bash
# Apply
kubectl apply -f definition.yaml
kubectl apply -f composition.yaml

# Create example claim
kubectl apply -f example-claim.yaml

# Verify
kubectl get myresource
kubectl get managed
```

## Patching and Transforms

### FromCompositeFieldPath

Copy values from claim to managed resources:

```yaml
patches:
  - type: FromCompositeFieldPath
    fromFieldPath: spec.parameters.size
    toFieldPath: spec.forProvider.vmSize
```

### ToCompositeFieldPath

Copy status from resources back to claim:

```yaml
patches:
  - type: ToCompositeFieldPath
    fromFieldPath: status.atProvider.endpoint
    toFieldPath: status.clusterEndpoint
```

### Transforms

Map values during patching:

```yaml
patches:
  - type: FromCompositeFieldPath
    fromFieldPath: spec.parameters.size
    toFieldPath: spec.forProvider.vmSize
    transforms:
      - type: map
        map:
          small: Standard_D2s_v3
          medium: Standard_D4s_v3
          large: Standard_D8s_v3
```

## Best Practices

### 1. Start Simple

Begin with basic parameters:

```yaml
# ✅ Good for v1
spec:
  parameters:
    size: medium

# ❌ Too complex for v1
spec:
  parameters:
    compute:
      nodePool:
        - name: system
          vmSize: Standard_D4s_v3
          minCount: 3
```

### 2. Use Enums

Limit choices to valid options:

```yaml
size:
  type: string
  enum:
    - small
    - medium
    - large
```

### 3. Set Defaults

Make it easy for users:

```yaml
location:
  type: string
  default: West Europe
```

### 4. Use Labels for Relationships

Link resources together:

```yaml
patches:
  - type: FromCompositeFieldPath
    fromFieldPath: spec.parameters.clusterName
    toFieldPath: metadata.labels.cluster
```

Then reference:

```yaml
spec:
  forProvider:
    resourceGroupNameSelector:
      matchLabels:
        cluster: my-cluster
```

### 5. Document Everything

Each composition should have:

- README.md explaining purpose
- Example claims
- Parameter documentation
- Size/cost guidelines

### 6. Version Your APIs

Use semantic versioning:

```yaml
versions:
  - name: v1alpha1  # Initial release
  - name: v1beta1   # Stable beta
  - name: v1        # Production ready
```

### 7. Handle Connection Secrets

Store credentials securely:

```yaml
spec:
  writeConnectionSecretsToNamespace: crossplane-system
  writeConnectionSecretToRef:
    name: my-cluster-kubeconfig
```

## Common Patterns

### Multi-Resource Pattern

One claim creates multiple resources:

```
Claim → Composition → [RG, VNet, Subnet, AKS, DB, Storage]
```

### Layered Pattern

Build on lower-level compositions:

```
DevEnvironment → [AKSCluster, Database]
                     ↓           ↓
                  [RG, VNet]  [RG, Server]
```

### Environment-Specific Pattern

Different compositions per environment:

```yaml
# development composition (small, less secure)
- name: aks-cluster-dev

# production composition (large, highly secure)
- name: aks-cluster-prod
```

## Troubleshooting

### XRD Not Found

```bash
# Check XRD exists
kubectl get xrd

# Describe for details
kubectl describe xrd xaksclusters.platform.example.org
```

### Composition Not Applied

```bash
# Check composition
kubectl get composition

# View details
kubectl describe composition aks-cluster-standard

# Check for errors
kubectl get events --sort-by='.lastTimestamp'
```

### Claim Stuck in Pending

```bash
# Check composite resource
kubectl get xakscluster

# Check managed resources
kubectl get managed

# View events
kubectl describe akscluster my-cluster
```

### Patches Not Working

```bash
# View composite resource YAML
kubectl get xakscluster -o yaml

# Check if values are being patched
kubectl get resourcegroup my-rg -o yaml | grep labels
```

## Migration from Direct Resources

### Before (Direct Resources)

```yaml
# User must create all of these:
apiVersion: azure.upbound.io/v1beta1
kind: ResourceGroup
---
apiVersion: network.azure.upbound.io/v1beta1
kind: VirtualNetwork
---
apiVersion: containerservice.azure.upbound.io/v1beta1
kind: KubernetesCluster
# ... 20+ more lines
```

### After (Composition)

```yaml
# User creates just this:
apiVersion: platform.example.org/v1alpha1
kind: AKSCluster
spec:
  parameters:
    size: medium
```

## When to Use Compositions

### Use Compositions When:

- ✅ Multiple resources always deployed together
- ✅ Multiple teams need same pattern
- ✅ Enforcing standards is important
- ✅ Simplifying user experience is valuable
- ✅ Building internal platform/PaaS

### Use Direct Resources When:

- ✅ One-off resources
- ✅ Learning Crossplane
- ✅ Maximum flexibility needed
- ✅ Small team, everyone knows cloud
- ✅ Prototyping

## Platform Engineering

Compositions are the foundation of **platform engineering**:

```
Platform Team → Creates compositions
     ↓
Developer API → Simple abstractions
     ↓
Self-Service → Teams provision own infrastructure
     ↓
Consistency → All resources follow standards
```

## Example Platform Hierarchy

```
Level 1: Cloud Resources (Crossplane Providers)
├── ResourceGroup
├── VirtualNetwork
├── KubernetesCluster
└── Database

Level 2: Compositions (Platform Team)
├── AKSCluster (uses RG, VNet, AKS)
├── Database (uses RG, Server, DB)
└── Storage (uses RG, Account)

Level 3: Higher-Level Compositions (Platform Team)
├── DevEnvironment (uses AKSCluster, Database)
├── ProductionSetup (uses AKSCluster, Database, Monitoring)
└── DataPlatform (uses AKSCluster, Database, Storage)

Level 4: Developer Interface
└── Developers create simple claims
```

## Next Steps

1. ✅ Review AKS cluster composition
1. ⏳ Create a test claim
1. ⏳ Build your own composition
1. ⏳ Design platform API for Atos project
1. ⏳ Document platform usage

## Resources

- [Crossplane Composition Docs](https://docs.crossplane.io/latest/concepts/compositions/)
- [Composition Functions](https://docs.crossplane.io/latest/concepts/composition-functions/)
- [Platform Engineering Guide](https://blog.crossplane.io/platform-engineering-with-crossplane/)
- [Upbound Marketplace](https://marketplace.upbound.io/)

-----

*Compositions for learning-flux-aks-crossplane repository*
