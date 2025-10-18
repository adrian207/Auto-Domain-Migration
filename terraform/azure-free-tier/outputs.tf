# Outputs for Azure Free Tier Deployment

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "guacamole_public_ip" {
  description = "Public IP address of Guacamole bastion"
  value       = var.enable_guacamole ? azurerm_public_ip.guacamole[0].ip_address : "N/A"
}

output "guacamole_url" {
  description = "URL to access Guacamole web interface"
  value       = var.enable_guacamole ? "https://${azurerm_public_ip.guacamole[0].ip_address}/" : "N/A"
}

output "guacamole_default_credentials" {
  description = "Default Guacamole login credentials (CHANGE AFTER FIRST LOGIN!)"
  value = var.enable_guacamole ? {
    username = "guacadmin"
    password = "guacadmin"
  } : null
  sensitive = true
}

output "ansible_controller_private_ip" {
  description = "Private IP address of Ansible controller"
  value       = azurerm_network_interface.ansible.private_ip_address
}

output "source_dc_private_ip" {
  description = "Private IP address of source domain controller"
  value       = azurerm_network_interface.source_dc.private_ip_address
}

output "target_dc_private_ip" {
  description = "Private IP address of target domain controller"
  value       = azurerm_network_interface.target_dc.private_ip_address
}

output "test_workstation_private_ip" {
  description = "Private IP address of test workstation"
  value       = azurerm_network_interface.test_workstation.private_ip_address
}

output "postgresql_fqdn" {
  description = "FQDN of PostgreSQL flexible server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "storage_account_name" {
  description = "Name of the storage account for migration artifacts"
  value       = azurerm_storage_account.main.name
}

output "ssh_private_key" {
  description = "Generated SSH private key (if no key was provided)"
  value       = var.ssh_public_key == "" ? tls_private_key.ssh[0].private_key_pem : "Using provided SSH key"
  sensitive   = true
}

output "next_steps" {
  description = "Next steps to complete the setup"
  value       = <<-EOT
  
  ========================================
  🎉 Azure Free Tier Deployment Complete!
  ========================================
  
  1. Access Guacamole Bastion:
     URL: https://${var.enable_guacamole ? azurerm_public_ip.guacamole[0].ip_address : "N/A"}/
     Username: guacadmin
     Password: guacadmin (CHANGE THIS IMMEDIATELY!)
  
  2. Configure Domain Controllers:
     Source DC: ${azurerm_network_interface.source_dc.private_ip_address}
     Target DC: ${azurerm_network_interface.target_dc.private_ip_address}
     
     - Log in via Guacamole (RDP)
     - Install AD DS role
     - Promote to domain controllers
     - Configure DNS
  
  3. Configure Ansible Controller:
     IP: ${azurerm_network_interface.ansible.private_ip_address}
     
     - SSH via Guacamole
     - Clone migration repo: cd /opt/migration/repo && git clone <repo-url> .
     - Configure inventory files
     - Run discovery playbooks
  
  4. Test Workstation:
     IP: ${azurerm_network_interface.test_workstation.private_ip_address}
     
     - Join to source domain
     - Create test user profiles
     - Run test migration
  
  5. PostgreSQL Databases:
     Host: ${azurerm_postgresql_flexible_server.main.fqdn}
     Databases: guacamole_db, migration_state, migration_telemetry
  
  6. Storage Account:
     Name: ${azurerm_storage_account.main.name}
     Containers: migration-artifacts, usmt-backups
  
  📖 Full documentation: docs/18_AZURE_FREE_TIER_IMPLEMENTATION.md
  
  💰 Estimated monthly cost: $0-5 (within free tier limits)
  
  EOT
}

