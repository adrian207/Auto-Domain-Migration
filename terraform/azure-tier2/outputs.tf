# Outputs for Azure Tier 2 (Production) Deployment

# =============================================================================
# RESOURCE GROUP
# =============================================================================

output "resource_group_name" {
  description = "Name of the primary resource group"
  value       = azurerm_resource_group.main.name
}

output "secondary_resource_group_name" {
  description = "Name of the secondary resource group (if using geo-redundancy)"
  value       = var.storage_account_replication == "GRS" ? azurerm_resource_group.secondary[0].name : "N/A"
}

# =============================================================================
# NETWORKING
# =============================================================================

output "guacamole_public_ip" {
  description = "Public IP address of Guacamole bastion"
  value       = var.enable_guacamole ? azurerm_public_ip.guacamole[0].ip_address : "N/A"
}

output "guacamole_url" {
  description = "URL to access Guacamole web interface"
  value       = var.enable_guacamole ? "https://${azurerm_public_ip.guacamole[0].ip_address}/" : "N/A"
}

output "ansible_load_balancer_ip" {
  description = "Load balancer IP for Ansible controllers (if HA enabled)"
  value       = var.num_ansible_controllers > 1 ? azurerm_public_ip.ansible_lb[0].ip_address : "N/A"
}

# =============================================================================
# COMPUTE RESOURCES
# =============================================================================

output "source_dc_ip" {
  description = "Private IP address of source domain controller"
  value       = azurerm_network_interface.source_dc.private_ip_address
}

output "target_dc_ip" {
  description = "Private IP address of target domain controller"
  value       = azurerm_network_interface.target_dc.private_ip_address
}

# =============================================================================
# CONTAINER APPS
# =============================================================================

output "ansible_container_app_name" {
  description = "Name of the Ansible Controller Container App"
  value       = azurerm_container_app.ansible.name
}

output "ansible_container_app_fqdn" {
  description = "FQDN of the Ansible Controller Container App (if ingress enabled)"
  value       = "Internal only - no external FQDN"
}

output "guacamole_container_app_url" {
  description = "URL to access Guacamole Container App"
  value       = var.enable_guacamole ? "https://${azurerm_container_app.guacamole[0].latest_revision_fqdn}/" : "N/A"
}

output "prometheus_container_app_url" {
  description = "Internal URL for Prometheus"
  value       = var.enable_monitoring_stack ? "http://${azurerm_container_app.prometheus[0].latest_revision_fqdn}:9090" : "N/A"
}

output "grafana_container_app_url" {
  description = "URL to access Grafana dashboard"
  value       = var.enable_monitoring_stack ? "https://${azurerm_container_app.grafana[0].latest_revision_fqdn}/" : "N/A"
}

output "container_app_environment_name" {
  description = "Name of the Container Apps Environment"
  value       = azurerm_container_app_environment.main.name
}

# =============================================================================
# DATABASE
# =============================================================================

output "postgresql_fqdn" {
  description = "FQDN of PostgreSQL flexible server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgresql_admin_username" {
  description = "PostgreSQL administrator username"
  value       = azurerm_postgresql_flexible_server.main.administrator_login
  sensitive   = true
}

output "postgresql_databases" {
  description = "List of PostgreSQL databases"
  value = [
    azurerm_postgresql_flexible_server_database.guacamole.name,
    azurerm_postgresql_flexible_server_database.statestore.name,
    azurerm_postgresql_flexible_server_database.telemetry.name,
    azurerm_postgresql_flexible_server_database.awx.name,
  ]
}

output "postgresql_ha_enabled" {
  description = "PostgreSQL high availability status"
  value       = var.enable_postgres_ha
}

# =============================================================================
# STORAGE
# =============================================================================

output "storage_account_name" {
  description = "Name of the storage account for migration artifacts"
  value       = azurerm_storage_account.main.name
}

output "storage_account_primary_endpoint" {
  description = "Primary blob endpoint of storage account"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "storage_containers" {
  description = "List of storage containers"
  value = [
    azurerm_storage_container.artifacts.name,
    azurerm_storage_container.usmt.name,
    azurerm_storage_container.logs.name,
    azurerm_storage_container.backups.name,
  ]
}

# =============================================================================
# SECURITY
# =============================================================================

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault.main[0].name : "N/A"
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault.main[0].vault_uri : "N/A"
}

# =============================================================================
# MONITORING AND LOGGING
# =============================================================================

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = var.enable_log_analytics ? azurerm_log_analytics_workspace.main[0].workspace_id : "N/A"
  sensitive   = true
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace name"
  value       = var.enable_log_analytics ? azurerm_log_analytics_workspace.main[0].name : "N/A"
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = var.enable_application_insights ? azurerm_application_insights.main[0].instrumentation_key : "N/A"
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = var.enable_application_insights ? azurerm_application_insights.main[0].connection_string : "N/A"
  sensitive   = true
}

# =============================================================================
# BACKUP AND RECOVERY
# =============================================================================

output "recovery_vault_name" {
  description = "Name of the Recovery Services vault"
  value       = var.enable_azure_backup ? azurerm_recovery_services_vault.main[0].name : "N/A"
}

output "backup_policy_name" {
  description = "Name of the backup policy"
  value       = var.enable_azure_backup ? azurerm_backup_policy_vm.daily[0].name : "N/A"
}

# =============================================================================
# SSH KEY
# =============================================================================

output "ssh_private_key" {
  description = "Generated SSH private key (if no key was provided)"
  value       = var.ssh_public_key == "" ? tls_private_key.ssh[0].private_key_pem : "Using provided SSH key"
  sensitive   = true
}

# =============================================================================
# CONFIGURATION SUMMARY
# =============================================================================

output "deployment_summary" {
  description = "Summary of deployment configuration"
  value = {
    environment             = var.environment
    location                = var.location
    availability_zones      = var.enable_availability_zones
    num_ansible_controllers = var.num_ansible_controllers
    postgres_ha_enabled     = var.enable_postgres_ha
    backup_enabled          = var.enable_azure_backup
    monitoring_enabled      = var.enable_log_analytics
    key_vault_enabled       = var.enable_key_vault
  }
}

# =============================================================================
# NEXT STEPS
# =============================================================================

output "next_steps" {
  description = "Next steps to complete the production setup"
  value       = <<-EOT
  
  ========================================================
  🎉 Azure Tier 2 (Production) Deployment Complete!
  ========================================================
  
  📊 Deployment Summary:
     - Environment: ${var.environment}
     - Location: ${var.location}
     - Availability Zones: ${var.enable_availability_zones ? "Enabled" : "Disabled"}
     - Ansible Controllers: ${var.num_ansible_controllers}
     - PostgreSQL HA: ${var.enable_postgres_ha ? "Enabled" : "Disabled"}
     - Backup: ${var.enable_azure_backup ? "Enabled" : "Disabled"}
  
  🔐 1. Access Guacamole Bastion (Container App):
     URL: ${var.enable_guacamole ? "https://${azurerm_container_app.guacamole[0].latest_revision_fqdn}/" : "N/A"}
     Username: guacadmin
     Password: guacadmin (CHANGE THIS IMMEDIATELY!)
     
     Security: Update password via Guacamole UI → Settings
     Architecture: Containerized with auto-scaling (1-2 replicas)
  
  💻 2. Ansible Controller (Container App):
     Name: ${azurerm_container_app.ansible.name}
     Environment: ${azurerm_container_app_environment.main.name}
     
     Setup:
     a) Container is deployed with your custom image: ${var.ansible_container_image}
     b) Scales automatically (1-3 replicas based on load)
     c) Persistent data stored in Azure File Share
     d) Run discovery playbooks via container exec:
        az containerapp exec -n ${azurerm_container_app.ansible.name} \\
          -g ${azurerm_resource_group.main.name} \\
          --command "ansible-playbook /opt/ansible/playbooks/00_discovery.yml"
  
  🗄️ 3. PostgreSQL Database (${var.enable_postgres_ha ? "High Availability" : "Standard"}):
     Host: ${azurerm_postgresql_flexible_server.main.fqdn}
     Username: ${azurerm_postgresql_flexible_server.main.administrator_login}
     Databases:
       - guacamole_db (Guacamole backend)
       - migration_state (Migration orchestration)
       - migration_telemetry (Metrics and logs)
       - awx_db (AWX/Ansible Tower)
       ${var.enable_monitoring_stack ? "- grafana_db (Monitoring)" : ""}
     
     ${var.enable_postgres_ha ? "HA Mode: Zone-redundant with automatic failover" : ""}
     Backup: ${var.postgres_backup_retention_days} days retention
     Geo-redundant: Enabled
  
  🏢 4. Domain Controllers:
     Source DC: ${azurerm_network_interface.source_dc.private_ip_address} (${var.source_domain_fqdn})
     Target DC: ${azurerm_network_interface.target_dc.private_ip_address} (${var.target_domain_fqdn})
     
     Post-deployment:
     a) RDP via Guacamole
     b) Promote to domain controllers
     c) Configure AD replication (if using trust model)
     d) Set up DNS forwarding
  
  📊 5. Monitoring ${var.enable_monitoring_stack ? "(Container Apps)" : ""}:
     ${var.enable_monitoring_stack ? "Prometheus: ${azurerm_container_app.prometheus[0].latest_revision_fqdn}:9090 (internal)" : ""}
     ${var.enable_monitoring_stack ? "Grafana: https://${azurerm_container_app.grafana[0].latest_revision_fqdn}/" : ""}
     ${var.enable_log_analytics ? "Log Analytics: ${azurerm_log_analytics_workspace.main[0].name}" : ""}
     ${var.enable_application_insights ? "Application Insights: Enabled" : ""}
     
     Default credentials: admin / admin (change immediately!)
     Architecture: Containerized with auto-scaling
  
  🔑 6. Key Vault ${var.enable_key_vault ? "(Enabled)" : ""}:
     ${var.enable_key_vault ? "Name: ${azurerm_key_vault.main[0].name}" : ""}
     ${var.enable_key_vault ? "URI: ${azurerm_key_vault.main[0].vault_uri}" : ""}
     
     Stored Secrets:
       - admin-password (VM admin password)
       - postgres-admin-password (PostgreSQL password)
  
  💾 7. Backup and Recovery:
     ${var.enable_azure_backup ? "Recovery Vault: ${azurerm_recovery_services_vault.main[0].name}" : "Backup: Disabled"}
     ${var.enable_azure_backup ? "Policy: Daily backups, ${var.backup_retention_days} days retention" : ""}
     ${var.enable_azure_backup ? "Protected VMs: All critical infrastructure" : ""}
  
  📦 8. Storage Account:
     Name: ${azurerm_storage_account.main.name}
     Replication: ${var.storage_account_replication}
     Containers:
       - migration-artifacts (Scripts, configs)
       - usmt-backups (User state data)
       - logs (Diagnostic logs)
       - backups (Manual backups)
  
  🔒 9. Security Best Practices:
     ✅ Review NSG rules (restrict to known IPs)
     ✅ Rotate all default passwords
     ✅ Configure Azure AD authentication for VMs
     ✅ Enable Azure Security Center recommendations
     ✅ Review and apply Key Vault access policies
     ✅ Enable MFA for all admin accounts
     ${var.enable_nsg_flow_logs ? "✅ NSG Flow Logs enabled" : "⚠️ Consider enabling NSG Flow Logs"}
  
  📖 Full Documentation:
     - Master Design: docs/00_MASTER_DESIGN.md
     - Azure Implementation: docs/18_AZURE_FREE_TIER_IMPLEMENTATION.md
     - Operations Runbook: docs/05_RUNBOOK_OPERATIONS.md
     - Rollback Procedures: docs/07_ROLLBACK_PROCEDURES.md
  
  💰 Estimated Monthly Cost:
     [Inference] Production configuration typically costs $800-2000/month depending on:
     - VM sizes and usage
     - PostgreSQL HA and storage
     - Data transfer
     - Backup storage
     
     Use Azure Cost Management to track actual spend.
  
  🚀 Ready to migrate? Start with discovery and test migrations before production!
  
  EOT
}


