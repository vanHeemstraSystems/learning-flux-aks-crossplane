# Crossplane Patterns - Managed Resources vs Compositions

This document explains the two main patterns for using Crossplane and when to use each.

## Pattern 1: Direct Managed Resources (Current Examples)

### What They Are

Direct Kubernetes representations of cloud resources using provider CRDs.

### Example

```yaml
apiVersion: azure.upbound.io/v1beta1
kind: ResourceGroup
metadata:
  name: my-rg
spec:
  forProvider:
    location: West Europe
```

### When to Use

- ✅ **Learning Crossplane**: Easiest to understand
- ✅ **Simple use cases**: One-off resources
- ✅ **Direct cloud control**: Need full provider API
- ✅ **Prototyping**: Quick iteration

### Pros

- Simple and direct
- Full access to all provider features
- Easy to understand what gets created
- No abstraction layer to learn

### Cons

- Users need to know cloud provider details
- No organizational standards enforcement
- Each resource defined separately
- Hard to maintain consistency

## Pattern 2: Compositions + Claims (Platform Pattern)

### What They Are

Custom abstractions that hide cloud complexity behind simple interfaces.

### Example

**What platform team creates (XRD + Composition)**:

```yaml
# Define the API
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xdatabases.acme.org
spec:
  group: acme.org
  names:
    kind: XDatabase
    plural: xdatabases
  claimNames:
    kind: Database
    plural: databases
  versions:
    - name: v1alpha1
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
                    size:
                      type: string
                      enum: [small, medium, large]
                    version:
                      type: string

---
# Define how to implement it
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: azure-postgresql-production
spec:
  compositeTypeRef:
    apiVersion: acme.org/v1alpha1
    kind: XDatabase
  resources:
    - name: postgresql-server
      base:
        apiVersion: dbforpostgresql.azure.upbound.io/v1beta1
        kind: Server
        spec:
          forProvider:
            # Default production settings
            version: "14"
            sslEnforcementEnabled: true
            backupRetentionDays: 30
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.size
          toFieldPath: spec.forProvider.skuName
          transforms:
            - type: map
              map:
                small: B_Gen5_1
                medium: GP_Gen5_2
                large: GP_Gen5_4
```

**What developers use (Claim)**:

```yaml
apiVersion: acme.org/v1alpha1
kind: Database
metadata:
  name: my-app-db
  namespace: dev
spec:
  parameters:
    size: medium
    version: "14"
```

### When to Use

- ✅ **Platform engineering**: Building internal platforms
- ✅ **Multiple teams**: Need consistent standards
- ✅ **Self-service**: Developers provision their own resources
- ✅ **Production systems**: Enterprise use cases

### Pros

- Hides cloud complexity from users
- Enforces organizational standards
- Reusable across teams
- Single place to update all instances
- Developer-friendly interface

### Cons

- More upfront work to create
- Requires platform team maintenance
- Abstraction can hide important details
- Learning curve for composition creation

## The Atos Project Context

For your **Atos Internal Developer Platform** project, you’ll likely want **both**:

### Phase 1: Learning (Now)

Use **Managed Resources** (current examples):

```yaml
# Direct Azure resources
apiVersion: network.azure.upbound.io/v1beta1
kind: VirtualNetwork
```

**Goal**: Understand Crossplane fundamentals

### Phase 2: Platform Building (Next)

Create **Compositions** for common patterns:

```yaml
# Platform abstraction
apiVersion: atos.platform/v1alpha1
kind: DevelopmentEnvironment
spec:
  team: backend-team
  size: medium
```

**Goal**: Build self-service platform for developers

## Recommended Repository Structure

```
learning-flux-aks-crossplane/
├── crossplane/
│   ├── claims/
│   │   └── examples/              # ← Current (Managed Resources)
│   │       ├── resourcegroup-claim.yaml
│   │       ├── storage-account-claim.yaml
│   │       └── network-claim.yaml
│   │
│   ├── compositions/              # ← Add this (Compositions)
│   │   ├── aks-cluster/
│   │   │   ├── definition.yaml   # XRD
│   │   │   ├── composition.yaml  # How to build it
│   │   │   └── example-claim.yaml
│   │   ├── postgresql/
│   │   └── development-environment/
│   │
│   └── providers/
│       └── provider-config.yaml
```

## When to Graduate from Managed Resources to Compositions

Consider moving to Compositions when:

1. **You’re repeating yourself**: Creating the same resource patterns multiple times
1. **Multiple teams need resources**: Each team shouldn’t need to know Azure details
1. **Standards are needed**: Want to enforce security/compliance policies
1. **Abstractions help**: “Give me a database” is better than “Create PostgreSQL server + database + firewall rules + backup policy”

## Example Progression

### Stage 1: Direct Managed Resource

```yaml
# User needs to know Azure specifics
apiVersion: dbforpostgresql.azure.upbound.io/v1beta1
kind: Server
spec:
  forProvider:
    resourceGroupName: my-rg
    location: West Europe
    version: "14"
    skuName: GP_Gen5_2
    storageMb: 51200
    backupRetentionDays: 7
    sslEnforcementEnabled: true
    # ... 20+ more fields
```

### Stage 2: Simple Composition

```yaml
# Simpler interface, still Azure-aware
apiVersion: database.acme.org/v1alpha1
kind: PostgreSQL
spec:
  size: medium
  version: "14"
  backups: standard
```

### Stage 3: Full Platform Abstraction

```yaml
# Cloud-agnostic, business-focused
apiVersion: platform.acme.org/v1alpha1
kind: Database
spec:
  type: relational
  size: medium
  compliance: gdpr
```

## Both Patterns Are Valid!

**There’s no “right” answer** - it depends on your use case:

|Use Case         |Pattern          |Why                              |
|-----------------|-----------------|---------------------------------|
|Learning         |Managed Resources|Clear, direct, easy to understand|
|Personal projects|Managed Resources|No abstraction overhead          |
|Small team       |Managed Resources|Everyone knows cloud provider    |
|Platform team    |Compositions     |Standards and self-service       |
|Multi-tenant     |Compositions     |Isolation and policy enforcement |
|Enterprise       |Compositions     |Governance and compliance        |

## For Your Learning Repository

**Keep your current examples** as Pattern 1 (Managed Resources)!

They’re perfect for:

- ✅ Learning Crossplane basics
- ✅ Understanding Azure provider
- ✅ Quick prototyping
- ✅ Teaching others

**Add Compositions** as a Pattern 2 section later:

- Show how to build abstractions
- Demonstrate platform engineering
- Prepare for Atos project patterns

## Terminology Clarification

The term “claim” is used in **two contexts**:

1. **Informal**: Any request for infrastructure (including Managed Resources)
1. **Formal**: Specifically the XRC (Composite Resource Claim) in the Composition pattern

Your current examples are **Managed Resources**, but calling them “claims” is fine colloquially since they’re “claiming” infrastructure!

## Next Steps for Your Repository

1. ✅ Keep current examples in `crossplane/claims/examples/`
1. ✅ Add note explaining these are Managed Resources
1. ⏳ Create `crossplane/compositions/` directory (future)
1. ⏳ Add example compositions for AKS, databases, etc.
1. ⏳ Show both patterns in documentation

This gives learners **both** perspectives!

## Resources

- [Crossplane Composition Docs](https://docs.crossplane.io/latest/concepts/compositions/)
- [Composition Functions](https://docs.crossplane.io/latest/concepts/composition-functions/)
- [Platform Engineering with Crossplane](https://blog.crossplane.io/platform-engineering-with-crossplane/)

-----

*Understanding the evolution of Crossplane patterns for learning-flux-aks-crossplane repository*
