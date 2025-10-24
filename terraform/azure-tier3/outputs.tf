# Terraform Outputs for Tier 3
# Purpose: Export important values for use by other tools

# =============================================================================
# AKS Cluster Outputs
# =============================================================================

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_kube_config" {
  description = "Kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "aks_node_resource_group" {
  description = "Resource group for AKS node resources"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

# =============================================================================
# Network Outputs
# =============================================================================

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "services_subnet_id" {
  description = "ID of the services subnet"
  value       = azurerm_subnet.services.id
}

output "load_balancer_public_ip" {
  description = "Public IP address of the load balancer"
  value       = azurerm_public_ip.lb.ip_address
}

# =============================================================================
# Storage Outputs
# =============================================================================

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the storage account"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "storage_account_primary_access_key" {
  description = "Primary access key for the storage account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

# =============================================================================
# Key Vault Outputs
# =============================================================================

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

# =============================================================================
# Monitoring Outputs
# =============================================================================

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

# =============================================================================
# Resource Group Output
# =============================================================================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}

# =============================================================================
# Passwords and Secrets
# =============================================================================

output "awx_admin_password" {
  description = "AWX admin password (stored in Key Vault)"
  value       = random_password.awx_admin.result
  sensitive   = true
}

# =============================================================================
# Connection Commands
# =============================================================================

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "aks_portal_url" {
  description = "Azure Portal URL for AKS cluster"
  value       = "https://portal.azure.com/#@/resource${azurerm_kubernetes_cluster.main.id}"
}

# =============================================================================
# Summary Output
# =============================================================================

output "deployment_summary" {
  description = "Summary of the deployment"
  value = {
    tier                 = "3 (Enterprise)"
    aks_cluster          = azurerm_kubernetes_cluster.main.name
    kubernetes_version   = azurerm_kubernetes_cluster.main.kubernetes_version
    system_nodes         = "${var.system_node_pool_min_count}-${var.system_node_pool_max_count}"
    worker_nodes         = "${var.worker_node_pool_min_count}-${var.worker_node_pool_max_count}"
    region               = azurerm_resource_group.main.location
    resource_group       = azurerm_resource_group.main.name
    monitoring_enabled   = var.enable_container_insights
    private_cluster      = var.enable_private_cluster
    auto_scaling_enabled = var.enable_auto_scaling
  }
}

