output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the created resource group"
  value       = azurerm_resource_group.main.id
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "kube_config" {
  description = "Structured kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config
  sensitive   = true
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet identity"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "kubelet_identity_client_id" {
  description = "Client ID of the kubelet identity"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].client_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity (needed for Crossplane)"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "principal_id" {
  description = "Principal ID of the system-assigned managed identity"
  value       = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

output "tenant_id" {
  description = "Tenant ID of the system-assigned managed identity"
  value       = azurerm_kubernetes_cluster.main.identity[0].tenant_id
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "acr_id" {
  description = "ID of the Azure Container Registry (if created)"
  value       = var.create_acr ? azurerm_container_registry.main[0].id : null
}

output "acr_login_server" {
  description = "Login server of the Azure Container Registry (if created)"
  value       = var.create_acr ? azurerm_container_registry.main[0].login_server : null
}

output "get_credentials_command" {
  description = "Command to get AKS credentials using Azure CLI"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "cluster_info" {
  description = "Summary of cluster information"
  value = {
    name               = azurerm_kubernetes_cluster.main.name
    resource_group     = azurerm_resource_group.main.name
    location           = azurerm_resource_group.main.location
    kubernetes_version = azurerm_kubernetes_cluster.main.kubernetes_version
    node_count         = var.node_count
    node_size          = var.node_size
    oidc_issuer_url    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  }
}

output "next_steps" {
  description = "Next steps after cluster creation"
  value = <<-EOT
    
    ✅ AKS Management Cluster Created Successfully!
    
    📋 Cluster Details:
       Name: ${azurerm_kubernetes_cluster.main.name}
       Resource Group: ${azurerm_resource_group.main.name}
       Location: ${azurerm_resource_group.main.location}
       Kubernetes Version: ${azurerm_kubernetes_cluster.main.kubernetes_version}
    
    🔑 Get Credentials:
       ${self.get_credentials_command}
    
    🚀 Next Steps:
       1. Get cluster credentials (command above)
       2. Verify connection: kubectl cluster-info
       3. Install Flux: See docs/03-install-flux.md
       4. Install Crossplane: See docs/04-install-crossplane.md
    
    🔗 OIDC Issuer (for Crossplane):
       ${azurerm_kubernetes_cluster.main.oidc_issuer_url}
    
    💰 Cost Reminder:
       This cluster costs approximately €5-7/day
       Stop when not in use: az aks stop --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}
    
  EOT
}
