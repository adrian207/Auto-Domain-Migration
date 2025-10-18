output "vm_id" {
  description = "Virtual machine ID"
  value       = var.os_type == "linux" ? azurerm_linux_virtual_machine.main[0].id : azurerm_windows_virtual_machine.main[0].id
}

output "vm_name" {
  description = "Virtual machine name"
  value       = var.vm_name
}

output "private_ip_address" {
  description = "Private IP address"
  value       = azurerm_network_interface.main.private_ip_address
}

output "public_ip_address" {
  description = "Public IP address"
  value       = var.create_public_ip ? azurerm_public_ip.main[0].ip_address : null
}

output "network_interface_id" {
  description = "Network interface ID"
  value       = azurerm_network_interface.main.id
}

output "identity_principal_id" {
  description = "Managed identity principal ID"
  value       = var.enable_managed_identity ? (var.os_type == "linux" ? azurerm_linux_virtual_machine.main[0].identity[0].principal_id : azurerm_windows_virtual_machine.main[0].identity[0].principal_id) : null
}


