# RBAC Role Assignments - Azure Tier 2 (Production)

# =============================================================================
# GUACAMOLE BASTION RBAC
# =============================================================================

# Grant Guacamole VM permission to update NSG rules
resource "azurerm_role_assignment" "guacamole_network_contributor" {
  count                = var.enable_guacamole ? 1 : 0
  scope                = azurerm_network_security_group.bastion.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_linux_virtual_machine.guacamole[0].identity[0].principal_id
}

# Grant Guacamole VM permission to read resource group
resource "azurerm_role_assignment" "guacamole_reader" {
  count                = var.enable_guacamole ? 1 : 0
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.guacamole[0].identity[0].principal_id
}

# Grant Guacamole access to Key Vault secrets
resource "azurerm_role_assignment" "guacamole_keyvault_reader" {
  count                = var.enable_guacamole && var.enable_key_vault ? 1 : 0
  scope                = azurerm_key_vault.main[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.guacamole[0].identity[0].principal_id
}

# =============================================================================
# ANSIBLE CONTROLLERS RBAC
# =============================================================================

# Grant Ansible controllers access to storage account
resource "azurerm_role_assignment" "ansible_storage_contributor" {
  count                = var.num_ansible_controllers
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.ansible[count.index].identity[0].principal_id
}

# Grant Ansible controllers read access to Key Vault
resource "azurerm_role_assignment" "ansible_keyvault_reader" {
  count                = var.enable_key_vault ? var.num_ansible_controllers : 0
  scope                = azurerm_key_vault.main[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.ansible[count.index].identity[0].principal_id
}

# Grant Ansible controllers monitoring access
resource "azurerm_role_assignment" "ansible_monitoring_reader" {
  count                = var.enable_log_analytics ? var.num_ansible_controllers : 0
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_linux_virtual_machine.ansible[count.index].identity[0].principal_id
}

# Grant Ansible controllers ability to manage VMs (for scaling operations)
resource "azurerm_role_assignment" "ansible_vm_contributor" {
  count                = var.num_ansible_controllers
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_linux_virtual_machine.ansible[count.index].identity[0].principal_id
}

# =============================================================================
# MONITORING VM RBAC
# =============================================================================

# Grant monitoring VM read access to all resources
resource "azurerm_role_assignment" "monitoring_reader" {
  count                = var.enable_monitoring_stack ? 1 : 0
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_linux_virtual_machine.monitoring[0].identity[0].principal_id
}

# Grant monitoring VM access to metrics
resource "azurerm_role_assignment" "monitoring_metrics_publisher" {
  count                = var.enable_monitoring_stack ? 1 : 0
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_linux_virtual_machine.monitoring[0].identity[0].principal_id
}

# Grant monitoring VM access to Log Analytics
resource "azurerm_role_assignment" "monitoring_log_analytics" {
  count                = var.enable_monitoring_stack && var.enable_log_analytics ? 1 : 0
  scope                = azurerm_log_analytics_workspace.main[0].id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azurerm_linux_virtual_machine.monitoring[0].identity[0].principal_id
}

# =============================================================================
# KEY VAULT ACCESS POLICIES
# =============================================================================

# Access policy for Ansible controllers
resource "azurerm_key_vault_access_policy" "ansible" {
  count        = var.enable_key_vault ? var.num_ansible_controllers : 0
  key_vault_id = azurerm_key_vault.main[0].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.ansible[count.index].identity[0].principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}

# Access policy for Guacamole
resource "azurerm_key_vault_access_policy" "guacamole" {
  count        = var.enable_guacamole && var.enable_key_vault ? 1 : 0
  key_vault_id = azurerm_key_vault.main[0].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.guacamole[0].identity[0].principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}

# Access policy for Monitoring
resource "azurerm_key_vault_access_policy" "monitoring" {
  count        = var.enable_monitoring_stack && var.enable_key_vault ? 1 : 0
  key_vault_id = azurerm_key_vault.main[0].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.monitoring[0].identity[0].principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}


