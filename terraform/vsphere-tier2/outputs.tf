# Outputs for vSphere Tier 2 (Production) Deployment

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
  value       = var.enable_guacamole ? cidrhost(var.network_cidr, 10) : "N/A"
}

output "ansible_controller_ips" {
  description = "IP addresses of Ansible/AWX controllers"
  value       = [for i in range(var.num_ansible_controllers) : cidrhost(var.network_cidr, 20 + i)]
}

output "postgres_cluster_ips" {
  description = "IP addresses of PostgreSQL cluster nodes"
  value       = [for i in range(var.num_postgres_nodes) : cidrhost(var.network_cidr, 30 + i)]
}

output "monitoring_ip" {
  description = "IP address of monitoring VM"
  value       = var.enable_monitoring ? cidrhost(var.network_cidr, 40) : "N/A"
}

output "source_dc_ip" {
  description = "IP address of source domain controller"
  value       = cidrhost(var.network_cidr, 100)
}

output "target_dc_ip" {
  description = "IP address of target domain controller"
  value       = cidrhost(var.network_cidr, 110)
}

output "vm_names" {
  description = "List of all deployed VM names"
  value = compact(concat(
    var.enable_guacamole ? [vsphere_virtual_machine.guacamole[0].name] : [],
    vsphere_virtual_machine.ansible[*].name,
    vsphere_virtual_machine.postgres[*].name,
    var.enable_monitoring ? [vsphere_virtual_machine.monitoring[0].name] : [],
    [vsphere_virtual_machine.source_dc.name],
    [vsphere_virtual_machine.target_dc.name]
  ))
}

output "ha_configuration" {
  description = "High availability configuration summary"
  value = {
    ansible_controllers = var.num_ansible_controllers
    postgres_nodes      = var.num_postgres_nodes
    drs_anti_affinity   = var.enable_drs_anti_affinity
    monitoring_enabled  = var.enable_monitoring
  }
}

output "next_steps" {
  description = "Next steps to complete the production setup"
  value       = <<-EOT
  
  =====================================================
  🎉 vSphere Tier 2 (Production) Deployment Complete!
  =====================================================
  
  📊 High Availability Configuration:
     - Ansible/AWX Controllers: ${var.num_ansible_controllers} (Load Balanced)
     - PostgreSQL Cluster: ${var.num_postgres_nodes} nodes (Patroni HA)
     - DRS Anti-Affinity: ${var.enable_drs_anti_affinity ? "Enabled" : "Disabled"}
     - Monitoring: ${var.enable_monitoring ? "Enabled" : "Disabled"}
  
  🔐 1. Access Guacamole Bastion:
     URL: https://${cidrhost(var.network_cidr, 10)}/
     Username: guacadmin
     Password: guacadmin (CHANGE IMMEDIATELY!)
  
  💻 2. Ansible/AWX Controllers (HA):
     IPs: ${join(", ", [for i in range(var.num_ansible_controllers) : cidrhost(var.network_cidr, 20 + i)])}
     
     Setup AWX (Ansible Tower) on each controller:
     - Install AWX via docker-compose or K3s
     - Configure cluster mode for HA
     - Share state via PostgreSQL cluster
  
  🗄️ 3. PostgreSQL Cluster (Patroni + etcd):
     IPs: ${join(", ", [for i in range(var.num_postgres_nodes) : cidrhost(var.network_cidr, 30 + i)])}
     
     Patroni provides:
     - Automatic failover
     - Leader election via etcd
     - Health checks and recovery
     
     Access via VIP or HAProxy load balancer
  
  📊 4. Monitoring (Prometheus + Grafana):
     IP: ${var.enable_monitoring ? cidrhost(var.network_cidr, 40) : "N/A"}
     Grafana: http://${var.enable_monitoring ? cidrhost(var.network_cidr, 40) : "N/A"}:3000
     Prometheus: http://${var.enable_monitoring ? cidrhost(var.network_cidr, 40) : "N/A"}:9090
  
  🏢 5. Domain Controllers:
     Source DC: ${cidrhost(var.network_cidr, 100)} (${var.source_domain_fqdn})
     Target DC: ${cidrhost(var.network_cidr, 110)} (${var.target_domain_fqdn})
     
     Promote to domain controllers and configure replication
  
  🔧 6. DRS Configuration:
     Anti-affinity rules ensure HA VMs run on different ESXi hosts
     Verify in vCenter: Clusters → ${var.cluster} → Configure → VM/Host Rules
  
  📖 Full Documentation: docs/19_VSPHERE_IMPLEMENTATION.md
  
  💰 Cost: On-premises (no cloud costs, only infrastructure)
  
  EOT
}


