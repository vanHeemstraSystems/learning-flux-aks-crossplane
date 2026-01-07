# 08 - Troubleshooting

## Overview

This guide provides solutions to common issues you may encounter when working with Flux, AKS, and Crossplane.

## General Troubleshooting Approach

### 1. Check Status

```bash
# Check all Crossplane resources
kubectl get managed --all-namespaces

# Check Flux status
flux get all

# Check provider health
kubectl get providers
```

### 2. Examine Events

```bash
# Get recent events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20

# Events for specific resource
kubectl describe <resource-type> <resource-name>
```

### 3. Check Logs

```bash
# Crossplane core logs
kubectl logs -n crossplane-system deployment/crossplane

# Provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-network

# Flux logs
kubectl logs -n flux-system deployment/source-controller
kubectl logs -n flux-system deployment/kustomize-controller
```

-----

## Flux Issues

### Issue: Bootstrap Fails

**Symptoms**:

```
✗ bootstrap failed: failed to commit sync manifests
```

**Causes & Solutions**:

1. **Invalid GitHub Token**

```bash
# Verify token has correct permissions:
# - repo (all)
# - workflow
# - admin:repo_hook

# Test token
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Create new token if needed
export GITHUB_TOKEN="new_token_here"
flux bootstrap github --owner=$GITHUB_USER --repository=$GITHUB_REPO --personal
```

1. **Repository Already Exists**

```bash
# Delete and recreate
flux uninstall --silent
git remote remove origin
rm -rf .git

# Re-bootstrap
flux bootstrap github --owner=$GITHUB_USER --repository=$GITHUB_REPO --personal
```

### Issue: Flux Not Syncing

**Symptoms**:

```
kubectl get gitrepository flux-system -n flux-system
# Shows: Not Ready
```

**Solutions**:

```bash
# Force reconciliation
flux reconcile source git flux-system

# Check for authentication issues
kubectl get secret -n flux-system flux-system -o yaml

# View source controller logs
kubectl logs -n flux-system deployment/source-controller

# Common fix: Re-create deploy key
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --personal \
  --force
```

### Issue: Kustomization Fails

**Symptoms**:

```
kustomization 'infrastructure' failed: validation failed
```

**Solutions**:

```bash
# Check kustomization status
kubectl describe kustomization infrastructure -n flux-system

# Validate kustomization locally
cd infrastructure/crossplane
kustomize build .

# Check for circular dependencies
flux tree kustomization infrastructure

# Force retry
flux reconcile kustomization infrastructure --with-source
```

-----

## Crossplane Issues

### Issue: Provider Not Becoming Healthy

**Symptoms**:

```
kubectl get providers
# Shows: HEALTHY = False
```

**Solutions**:

1. **Check Provider Pod**

```bash
# Find provider pod
kubectl get pods -n crossplane-system | grep provider-azure

# Check pod status
kubectl describe pod -n crossplane-system <provider-pod-name>

# View logs
kubectl logs -n crossplane-system <provider-pod-name>
```

1. **Image Pull Errors**

```bash
# Check image pull policy
kubectl get provider provider-azure-network -o yaml | grep -A 5 packagePullPolicy

# Verify internet connectivity from cluster
kubectl run curl-test --image=curlimages/curl --rm -it -- curl -I https://xpkg.upbound.io
```

1. **Force Reinstall**

```bash
# Delete and recreate provider
kubectl delete provider provider-azure-network
kubectl apply -f infrastructure/crossplane/provider-azure.yaml

# Wait for healthy status
kubectl wait --for=condition=healthy provider/provider-azure-network --timeout=300s
```

### Issue: Resources Stuck in “Creating”

**Symptoms**:

```
kubectl get resourcegroup
# Shows: READY = False, STATUS = Creating (for >10 minutes)
```

**Solutions**:

1. **Check Resource Details**

```bash
# Describe resource
kubectl describe resourcegroup <name>

# Look at status.conditions
kubectl get resourcegroup <name> -o yaml | grep -A 20 status

# Common issues in conditions:
# - Authentication failures
# - Permission denied
# - Resource quota exceeded
# - Network errors
```

1. **Check Provider Logs**

```bash
# Get provider logs for this resource
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-network | grep <resource-name>
```

1. **Verify Azure**

```bash
# Check if resource exists in Azure
az group show --name <resource-name>

# Check if Crossplane has correct permissions
az role assignment list --assignee $AZURE_CLIENT_ID
```

### Issue: Authentication Failures

**Symptoms**:

```
Error: Failed to get credentials: cannot get Azure creds from Azure secret
```

**Solutions**:

1. **Verify Secret Exists**

```bash
# Check secret
kubectl get secret azure-credentials -n crossplane-system

# View secret content (base64 encoded)
kubectl get secret azure-credentials -n crossplane-system -o yaml
```

1. **Test Service Principal**

```bash
# Login with service principal
az login --service-principal \
  -u $AZURE_CLIENT_ID \
  -p $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID

# If this fails, recreate service principal
export SP_NAME="crossplane-sp-$(date +%s)"
az ad sp create-for-rbac \
  --name "${SP_NAME}" \
  --role Contributor \
  --scopes "/subscriptions/${AZURE_SUBSCRIPTION_ID}"
```

1. **Recreate Secret**

```bash
# Delete old secret
kubectl delete secret azure-credentials -n crossplane-system

# Create new credentials file
cat > azure-credentials.json <<EOF
{
  "clientId": "${AZURE_CLIENT_ID}",
  "clientSecret": "${AZURE_CLIENT_SECRET}",
  "subscriptionId": "${AZURE_SUBSCRIPTION_ID}",
  "tenantId": "${AZURE_TENANT_ID}",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
EOF

# Create new secret
kubectl create secret generic azure-credentials \
  -n crossplane-system \
  --from-file=credentials=./azure-credentials.json

rm azure-credentials.json
```

### Issue: Resource Deletion Stuck

**Symptoms**:

```
kubectl delete resourcegroup my-rg
# Hangs indefinitely
```

**Solutions**:

1. **Check Finalizers**

```bash
# View finalizers
kubectl get resourcegroup my-rg -o yaml | grep -A 5 finalizers

# Remove finalizer if stuck
kubectl patch resourcegroup my-rg -p '{"metadata":{"finalizers":[]}}' --type=merge
```

1. **Force Delete from Azure**

```bash
# Delete from Azure manually
az group delete --name my-rg --yes --no-wait

# Then remove from Kubernetes
kubectl delete resourcegroup my-rg --force --grace-period=0
```

-----

## AKS-Specific Issues

### Issue: AKS Cluster Fails to Provision

**Symptoms**:

```
KubernetesCluster stuck in "Creating" for >20 minutes
```

**Solutions**:

1. **Check Quota Limits**

```bash
# Check VM quota
az vm list-usage --location "West Europe" -o table | grep Standard_D

# Request quota increase if needed
az support tickets create \
  --title "Increase D-series VM quota" \
  --description "Need more D-series VMs for AKS"
```

1. **Verify Network Configuration**

```bash
# Check CIDR overlaps
# Service CIDR: 10.2.0.0/24
# Pod subnet: 10.0.1.0/24
# These must not overlap

# Verify DNS service IP is within service CIDR
# dnsServiceIp: 10.2.0.10 (valid if service CIDR is 10.2.0.0/24)
```

1. **Check Resource Dependencies**

```bash
# Ensure subnet exists
kubectl get subnet -o yaml

# Ensure VNet exists
kubectl get virtualnetwork -o yaml

# Check if subnet has vnetSubnetId set
kubectl get subnet <subnet-name> -o jsonpath='{.status.atProvider.id}'
```

### Issue: Cannot Access AKS Cluster

**Symptoms**:

```
kubectl --kubeconfig=cluster-kubeconfig.yaml get nodes
# Error: Unable to connect to the server
```

**Solutions**:

1. **Verify Kubeconfig**

```bash
# Check if secret exists
kubectl get secret <cluster-name>-kubeconfig -n default

# Extract kubeconfig
kubectl get secret <cluster-name>-kubeconfig -n default \
  -o jsonpath='{.data.kubeconfig}' | base64 -d > kubeconfig.yaml

# Test connection
export KUBECONFIG=kubeconfig.yaml
kubectl get nodes
```

1. **Check AKS Cluster Status**

```bash
# Verify cluster is running
az aks show \
  --resource-group <rg-name> \
  --name <cluster-name> \
  --query provisioningState

# Get credentials from Azure directly
az aks get-credentials \
  --resource-group <rg-name> \
  --name <cluster-name> \
  --overwrite-existing
```

1. **Network Access Issues**

```bash
# If using private cluster, ensure you're in the allowed network
# Check authorized IP ranges
az aks show \
  --resource-group <rg-name> \
  --name <cluster-name> \
  --query apiServerAccessProfile

# Add your IP if needed
az aks update \
  --resource-group <rg-name> \
  --name <cluster-name> \
  --api-server-authorized-ip-ranges "$(curl -s ifconfig.me)/32"
```

-----

## Performance Issues

### Issue: Slow Reconciliation

**Symptoms**:

- Resources take >5 minutes to create
- Frequent timeouts

**Solutions**:

1. **Increase Provider Resources**

```yaml
# In helmrelease.yaml
values:
  resourcesCrossplane:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 200m
      memory: 512Mi
```

1. **Adjust Reconciliation Intervals**

```yaml
# For Flux Kustomization
spec:
  interval: 5m0s  # Increase from 1m0s
  
# For HelmRelease
spec:
  interval: 10m0s  # Increase from 5m0s
```

1. **Enable Parallel Processing**

```yaml
# Crossplane configuration
args:
  - --max-reconcile-rate=20  # Default is 10
```

### Issue: High Memory Usage

**Symptoms**:

- Crossplane pods being OOMKilled
- Cluster nodes running out of memory

**Solutions**:

1. **Increase Memory Limits**

```yaml
resourcesCrossplane:
  limits:
    memory: 2Gi  # Increase from 512Mi
  requests:
    memory: 1Gi  # Increase from 256Mi
```

1. **Reduce Managed Resources**

```bash
# Check number of resources
kubectl get managed --all-namespaces | wc -l

# Consider using fewer provider families
# Or splitting across multiple management clusters
```

-----

## Common Error Messages

### “providerconfig.meta.pkg.crossplane.io not found”

```bash
# Wait for provider to install ProviderConfig CRD
kubectl wait --for=condition=healthy provider/provider-azure-network --timeout=300s

# Or manually check
kubectl get crd providerconfigs.azure.upbound.io
```

### “cannot resolve managed resource references”

```bash
# Check if referenced resources exist
kubectl get <referenced-resource-type>

# Verify labels match selectors
kubectl get <resource-type> <resource-name> -o yaml | grep -A 5 labels
```

### “rate limit exceeded”

```bash
# Azure API rate limit hit
# Wait a few minutes, then retry

# Or increase provider replicas
kubectl scale deployment provider-azure-network \
  -n crossplane-system --replicas=2
```

-----

## Debugging Techniques

### Enable Verbose Logging

```bash
# Crossplane debug logs
kubectl set env deployment/crossplane \
  -n crossplane-system \
  --containers=crossplane \
  CROSSPLANE_TRACE=true

# Provider debug logs
kubectl set env deployment/provider-azure-network \
  -n crossplane-system \
  --containers=provider-azure-network \
  DEBUG=true
```

### Capture Complete State

```bash
# Create debug bundle
mkdir debug-$(date +%Y%m%d-%H%M%S)
cd debug-*

# Crossplane state
kubectl get managed -A -o yaml > managed-resources.yaml
kubectl get providers -o yaml > providers.yaml
kubectl get providerconfigs -A -o yaml > providerconfigs.yaml

# Flux state
flux get all --all-namespaces > flux-status.txt

# Logs
kubectl logs -n crossplane-system deployment/crossplane > crossplane-logs.txt
kubectl logs -n flux-system deployment/source-controller > source-controller-logs.txt

# Events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' > events.txt

cd ..
tar -czf debug-bundle.tar.gz debug-*
```

-----

## Getting Help

### Community Resources

1. **Crossplane Slack**: https://slack.crossplane.io/
1. **Flux Slack**: https://fluxcd.io/slack/
1. **GitHub Discussions**:
- Crossplane: https://github.com/crossplane/crossplane/discussions
- Flux: https://github.com/fluxcd/flux2/discussions

### Useful Commands Reference

```bash
# Quick health check
flux check
kubectl get providers
kubectl get managed --all-namespaces

# Force reconciliation
flux reconcile source git flux-system
flux reconcile kustomization infrastructure

# View resource status
kubectl describe <resource-type> <resource-name>
kubectl get <resource-type> <resource-name> -o yaml

# Check logs
kubectl logs -n crossplane-system deployment/crossplane --tail=100
kubectl logs -n flux-system deployment/kustomize-controller --tail=100

# Delete stuck resources
kubectl patch <resource-type> <resource-name> -p '{"metadata":{"finalizers":[]}}' --type=merge
kubectl delete <resource-type> <resource-name> --force --grace-period=0
```

### Emergency Recovery

If everything is broken:

```bash
# 1. Uninstall Flux
flux uninstall --silent

# 2. Delete Crossplane
helm uninstall crossplane -n crossplane-system
kubectl delete namespace crossplane-system

# 3. Clean up CRDs
kubectl get crds | grep crossplane | awk '{print $1}' | xargs kubectl delete crd
kubectl get crds | grep fluxcd | awk '{print $1}' | xargs kubectl delete crd

# 4. Re-bootstrap from scratch
flux bootstrap github --owner=$GITHUB_USER --repository=$GITHUB_REPO --personal
```

-----

## Prevention Best Practices

1. **Test in Development First**
- Never test new configurations in production
- Use separate Azure subscriptions for dev/prod
1. **Monitor Continuously**
- Set up alerts for failed reconciliations
- Monitor Azure quotas and limits
1. **Version Control Everything**
- All configurations in Git
- Use branches and pull requests
- Tag releases
1. **Document Changes**
- Keep a changelog
- Document custom configurations
- Share lessons learned
1. **Regular Backups**
- Export Crossplane resources weekly
- Back up Git repositories
- Document recovery procedures

-----

## Conclusion

Most issues can be resolved by:

1. Checking resource status and events
1. Reviewing logs
1. Verifying authentication
1. Testing connectivity

When in doubt:

- Start with `kubectl describe`
- Check provider logs
- Verify Azure portal
- Ask community for help

-----

*Keep this guide handy during your Crossplane journey!*
