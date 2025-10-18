# RBAC Role Assignments for Managed Identities

# Grant Guacamole VM permission to update NSG rules
resource "azurerm_role_assignment" "guacamole_network_contributor" {
  count                = var.enable_guacamole ? 1 : 0
  scope                = azurerm_network_security_group.bastion.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_linux_virtual_machine.guacamole[0].identity[0].principal_id
}

# Grant Guacamole VM permission to read resource group (for NSG operations)
resource "azurerm_role_assignment" "guacamole_reader" {
  count                = var.enable_guacamole ? 1 : 0
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.guacamole[0].identity[0].principal_id
}

