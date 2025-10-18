# vSphere Tier 2 (Production) Variables
# Enterprise-grade deployment with HA, DRS, and scalability

# =============================================================================
# vSphere Connection
# =============================================================================

variable "vsphere_server" {
  description = "vCenter server FQDN or IP"
  type        = string
}

variable "vsphere_user" {
  description = "vSphere username"
  type        = string
}

variable "vsphere_password" {
  description = "vSphere password"
  type        = string
  sensitive   = true
}

variable "allow_unverified_ssl" {
  description = "Allow unverified SSL certificates (set to false in production)"
  type        = bool
  default     = false
}

# =============================================================================
# vSphere Infrastructure
# =============================================================================

variable "datacenter" {
  description = "vSphere datacenter name"
  type        = string
}

variable "cluster" {
  description = "vSphere cluster name (must have HA and DRS enabled)"
  type        = string
}

variable "datastore" {
  description = "vSphere datastore name for VM storage"
  type        = string
}

variable "datastore_backup" {
  description = "Secondary datastore for backups"
  type        = string
  default     = ""
}

variable "network_name" {
  description = "vSphere port group / network name"
  type        = string
  default     = "VM Network"
}

# =============================================================================
# Project Configuration
# =============================================================================

variable "project_name" {
  description = "Project name used for VM naming"
  type        = string
  default     = "admigration"
}

variable "environment" {
  description = "Environment name (prod, staging)"
  type        = string
  default     = "prod"
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "administrator"
}

variable "admin_password" {
  description = "Admin password for VMs (min 12 chars, complex)"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for Linux VMs"
  type        = string
}

variable "domain" {
  description = "DNS domain for VMs"
  type        = string
  default     = "migration.corp.local"
}

variable "dns_servers" {
  description = "List of DNS server IPs"
  type        = list(string)
}

variable "ntp_servers" {
  description = "List of NTP servers"
  type        = list(string)
  default     = ["time.nist.gov"]
}

# =============================================================================
# VM Templates
# =============================================================================

variable "template_ubuntu_22" {
  description = "Name of Ubuntu 22.04 VM template"
  type        = string
  default     = "ubuntu-22.04-template"
}

variable "template_windows_server_2022" {
  description = "Name of Windows Server 2022 VM template"
  type        = string
  default     = "windows-server-2022-template"
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "network_cidr" {
  description = "Network CIDR for IP allocation"
  type        = string
  default     = "10.0.0.0/16"
}

variable "gateway" {
  description = "Default gateway IP"
  type        = string
}

variable "netmask" {
  description = "Netmask (e.g., 24 for /24)"
  type        = number
  default     = 24
}

# =============================================================================
# High Availability Configuration
# =============================================================================

variable "num_ansible_controllers" {
  description = "Number of Ansible/AWX controller VMs (2-3 recommended for HA)"
  type        = number
  default     = 2

  validation {
    condition     = var.num_ansible_controllers >= 1 && var.num_ansible_controllers <= 5
    error_message = "Number of Ansible controllers must be between 1 and 5."
  }
}

variable "num_postgres_nodes" {
  description = "Number of PostgreSQL nodes for Patroni cluster (3 recommended)"
  type        = number
  default     = 3

  validation {
    condition     = var.num_postgres_nodes >= 1 && var.num_postgres_nodes <= 5
    error_message = "Number of PostgreSQL nodes must be between 1 and 5."
  }
}

variable "enable_drs_anti_affinity" {
  description = "Enable DRS anti-affinity rules for HA VMs"
  type        = bool
  default     = true
}

variable "enable_vm_anti_affinity" {
  description = "Enable VM-to-VM anti-affinity rules"
  type        = bool
  default     = true
}

# =============================================================================
# VM Resource Allocation (Production Sizing)
# =============================================================================

variable "guacamole_vcpu" {
  description = "Number of vCPUs for Guacamole"
  type        = number
  default     = 4
}

variable "guacamole_memory_mb" {
  description = "Memory in MB for Guacamole"
  type        = number
  default     = 8192
}

variable "ansible_vcpu" {
  description = "Number of vCPUs for Ansible controllers"
  type        = number
  default     = 8
}

variable "ansible_memory_mb" {
  description = "Memory in MB for Ansible controllers"
  type        = number
  default     = 32768
}

variable "postgres_vcpu" {
  description = "Number of vCPUs for PostgreSQL nodes"
  type        = number
  default     = 4
}

variable "postgres_memory_mb" {
  description = "Memory in MB for PostgreSQL nodes"
  type        = number
  default     = 16384
}

variable "monitoring_vcpu" {
  description = "Number of vCPUs for monitoring"
  type        = number
  default     = 4
}

variable "monitoring_memory_mb" {
  description = "Memory in MB for monitoring"
  type        = number
  default     = 16384
}

variable "dc_vcpu" {
  description = "Number of vCPUs for domain controllers"
  type        = number
  default     = 4
}

variable "dc_memory_mb" {
  description = "Memory in MB for domain controllers"
  type        = number
  default     = 8192
}

variable "disk_size_gb" {
  description = "Default disk size in GB"
  type        = number
  default     = 200
}

# =============================================================================
# PostgreSQL Configuration
# =============================================================================

variable "postgres_password" {
  description = "Password for PostgreSQL admin user"
  type        = string
  sensitive   = true
}

variable "postgres_data_disk_size_gb" {
  description = "PostgreSQL data disk size in GB"
  type        = number
  default     = 500
}

# =============================================================================
# Domain Configuration
# =============================================================================

variable "source_domain_fqdn" {
  description = "Source Active Directory domain FQDN"
  type        = string
  default     = "source.corp.local"
}

variable "target_domain_fqdn" {
  description = "Target Active Directory domain FQDN"
  type        = string
  default     = "target.corp.local"
}

# =============================================================================
# Feature Flags
# =============================================================================

variable "enable_guacamole" {
  description = "Enable Apache Guacamole bastion host"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable Prometheus/Grafana monitoring"
  type        = bool
  default     = true
}

variable "enable_ha_postgres" {
  description = "Enable PostgreSQL HA cluster with Patroni"
  type        = bool
  default     = true
}

variable "num_test_workstations" {
  description = "Number of test workstations to deploy"
  type        = number
  default     = 0
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Tags to apply to VMs (as notes)"
  type        = map(string)
  default = {
    Project     = "AD-Migration"
    Environment = "Production"
    ManagedBy   = "Terraform"
    Tier        = "2"
    Author      = "Adrian Johnson"
    CostCenter  = "IT"
  }
}


