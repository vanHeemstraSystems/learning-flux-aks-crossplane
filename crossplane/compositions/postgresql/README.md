# PostgreSQL Composition

This composition provides a managed PostgreSQL Flexible Server with databases, configuration, and security settings.

## What This Creates

When you create a PostgreSQL instance using this composition, Crossplane automatically provisions:

1. **Resource Group** - Container for database resources
1. **PostgreSQL Flexible Server** - Managed database server
1. **Server Configurations** - SSL and connection limits
1. **Database** - Application database
1. **Firewall Rule** - Allow Azure services
1. **Connection Secret** - Credentials for applications

## Files

|File                |Purpose             |
|--------------------|--------------------|
|`definition.yaml`   |XRD (API definition)|
|`composition.yaml`  |Implementation      |
|`example-claim.yaml`|Usage example       |
|`README.md`         |This file           |

## Prerequisites

### 1. Network with Database Subnet

```bash
kubectl apply -f ../networking/example-claim.yaml
```

### 2. Admin Password Secret

```bash
kubectl create secret generic postgres-admin-password \
  --namespace default \
  --from-literal=password='YourSecurePassword123!'
```

## Size Options

|Size  |vCores|Memory|Connections|Cost/Month|
|------|------|------|-----------|----------|
|small |1     |2 GB  |100        |~€25-30   |
|medium|2     |8 GB  |200        |~€150-180 |
|large |4     |16 GB |400        |~€300-360 |

## Quick Start

```yaml
apiVersion: platform.example.org/v1alpha1
kind: PostgreSQLInstance
metadata:
  name: my-database
spec:
  parameters:
    instanceName: my-database
    size: small
    version: "14"
    networkRef:
      name: my-network
    adminPasswordSecretRef:
      name: postgres-admin-password
      namespace: default
```

For complete documentation, see the downloadable README.md file.

-----

*PostgreSQL Composition for learning-flux-aks-crossplane repository*
