# Outputs for vSphere Tier 1 (Demo) Deployment

output "resource_pool_id" {
  description = "Resource pool ID for migration VMs"
  value       = vsphere_resource_pool.migration_pool.id
}

output "vm_folder_path" {
  description = "Path to VM folder"
  value       = vsphere_folder.vm_folder.path
}

output "guacamole_ip" {
  description = "IP address of Guacamole bastion"
  value       = var.enable_guacamole ? var.guacamole_ip : "N/A"
}

output "guacamole_url" {
  description = "URL to access Guacamole web interface"
  value       = var.enable_guacamole ? "https://${var.guacamole_ip}/" : "N/A"
}

output "guacamole_default_credentials" {
  description = "Default Guacamole login credentials (CHANGE AFTER FIRST LOGIN!)"
  value = var.enable_guacamole ? {
    username = "guacadmin"
    password = "guacadmin"
  } : null
  sensitive = true
}

output "ansible_controller_ip" {
  description = "IP address of Ansible controller"
  value       = var.ansible_controller_ip
}

output "postgres_ip" {
  description = "IP address of PostgreSQL server"
  value       = var.postgres_ip
}

output "source_dc_ip" {
  description = "IP address of source domain controller"
  value       = var.source_dc_ip
}

output "target_dc_ip" {
  description = "IP address of target domain controller"
  value       = var.target_dc_ip
}

output "test_workstation_ips" {
  description = "IP addresses of test workstations"
  value       = [for i in range(var.num_test_workstations) : cidrhost(var.network_cidr, 100 + i)]
}

output "vm_names" {
  description = "List of all deployed VM names"
  value = compact(concat(
    var.enable_guacamole ? [vsphere_virtual_machine.guacamole[0].name] : [],
    [vsphere_virtual_machine.ansible.name],
    [vsphere_virtual_machine.postgres.name],
    [vsphere_virtual_machine.source_dc.name],
    [vsphere_virtual_machine.target_dc.name],
    vsphere_virtual_machine.test_workstation[*].name
  ))
}

output "next_steps" {
  description = "Next steps to complete the setup"
  value       = <<-EOT
  
  ========================================
  🎉 vSphere Tier 1 Deployment Complete!
  ========================================
  
  1. Access Guacamole Bastion:
     URL: https://${var.guacamole_ip}/
     Username: guacadmin
     Password: guacadmin (CHANGE THIS IMMEDIATELY!)
     
     NOTE: If using self-signed cert, accept browser warning
  
  2. Configure Domain Controllers:
     Source DC: ${var.source_dc_ip} (Domain: ${var.source_domain_fqdn})
     Target DC: ${var.target_dc_ip} (Domain: ${var.target_domain_fqdn})
     
     a) Log in via Guacamole (RDP)
     b) Install AD DS role:
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
     c) Promote to domain controller:
        Install-ADDSForest -DomainName "${var.source_domain_fqdn}" `
          -DomainMode "WinThreshold" -ForestMode "WinThreshold" `
          -InstallDns -Force
     d) Reboot
  
  3. Configure PostgreSQL Server:
     IP: ${var.postgres_ip}
     Databases: guacamole_db, migration_state, migration_telemetry
     User: ${var.admin_username}
     
     PostgreSQL should be auto-configured via cloud-init.
     Test connection from Ansible controller:
       psql -h ${var.postgres_ip} -U ${var.admin_username} -d migration_state
  
  4. Configure Ansible Controller:
     IP: ${var.ansible_controller_ip}
     
     a) SSH via Guacamole or directly
     b) Clone migration repo:
        cd /opt/migration/repo
        git clone https://github.com/adrian207/Auto-Domain-Migration.git .
     c) Configure inventory files
     d) Run discovery playbooks:
        ansible-playbook playbooks/00_discovery.yml
  
  5. Test Workstations:
     IPs: ${join(", ", [for i in range(var.num_test_workstations) : cidrhost(var.network_cidr, 100 + i)])}
     
     a) Join to source domain
     b) Create test user profiles
     c) Run test migration
  
  6. Network Configuration:
     Network: ${var.network_cidr}
     Gateway: ${var.gateway}
     DNS: ${join(", ", var.dns_servers)}
     Domain: ${var.domain}
  
  📖 Full documentation: docs/19_VSPHERE_IMPLEMENTATION.md
  
  💰 Cost: On-premises infrastructure (no cloud costs)
  
  EOT
}


