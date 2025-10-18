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
  default     = true
}

variable "datacenter" {
  description = "vSphere datacenter name"
  type        = string
}

variable "cluster" {
  description = "vSphere cluster name"
  type        = string
}

variable "datastore" {
  description = "vSphere datastore name for VM storage"
  type        = string
}

variable "datastore_iso" {
  description = "vSphere datastore name for ISO files"
  type        = string
  default     = ""
}

variable "network_name" {
  description = "vSphere port group / network name"
  type        = string
  default     = "VM Network"
}

variable "project_name" {
  description = "Project name used for VM naming"
  type        = string
  default     = "admigration"
}

variable "environment" {
  description = "Environment name (demo, dev, prod)"
  type        = string
  default     = "demo"
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
  default     = "migration.local"
}

variable "dns_servers" {
  description = "List of DNS server IPs"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "ntp_servers" {
  description = "List of NTP servers"
  type        = list(string)
  default     = ["time.nist.gov"]
}

# Template Configuration
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

variable "template_windows_11" {
  description = "Name of Windows 11 VM template"
  type        = string
  default     = "windows-11-template"
}

# Network Configuration
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

# IP Address Assignments
variable "guacamole_ip" {
  description = "Static IP for Guacamole bastion"
  type        = string
  default     = "10.0.1.10"
}

variable "ansible_controller_ip" {
  description = "Static IP for Ansible controller"
  type        = string
  default     = "10.0.2.10"
}

variable "source_dc_ip" {
  description = "Static IP for source domain controller"
  type        = string
  default     = "10.0.10.10"
}

variable "target_dc_ip" {
  description = "Static IP for target domain controller"
  type        = string
  default     = "10.0.20.10"
}

variable "postgres_ip" {
  description = "Static IP for PostgreSQL server"
  type        = string
  default     = "10.0.2.20"
}

# PostgreSQL Configuration
variable "postgres_password" {
  description = "Password for PostgreSQL admin user"
  type        = string
  sensitive   = true
}

# VM Resource Allocation
variable "guacamole_vcpu" {
  description = "Number of vCPUs for Guacamole"
  type        = number
  default     = 2
}

variable "guacamole_memory_mb" {
  description = "Memory in MB for Guacamole"
  type        = number
  default     = 2048
}

variable "ansible_vcpu" {
  description = "Number of vCPUs for Ansible controller"
  type        = number
  default     = 2
}

variable "ansible_memory_mb" {
  description = "Memory in MB for Ansible controller"
  type        = number
  default     = 4096
}

variable "dc_vcpu" {
  description = "Number of vCPUs for domain controllers"
  type        = number
  default     = 2
}

variable "dc_memory_mb" {
  description = "Memory in MB for domain controllers"
  type        = number
  default     = 4096
}

variable "postgres_vcpu" {
  description = "Number of vCPUs for PostgreSQL"
  type        = number
  default     = 2
}

variable "postgres_memory_mb" {
  description = "Memory in MB for PostgreSQL"
  type        = number
  default     = 4096
}

variable "workstation_vcpu" {
  description = "Number of vCPUs for test workstations"
  type        = number
  default     = 2
}

variable "workstation_memory_mb" {
  description = "Memory in MB for test workstations"
  type        = number
  default     = 4096
}

variable "disk_size_gb" {
  description = "Default disk size in GB"
  type        = number
  default     = 100
}

# Feature Flags
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

variable "num_test_workstations" {
  description = "Number of test workstations to deploy"
  type        = number
  default     = 2
}

variable "source_domain_fqdn" {
  description = "Source Active Directory domain FQDN"
  type        = string
  default     = "source.local"
}

variable "target_domain_fqdn" {
  description = "Target Active Directory domain FQDN"
  type        = string
  default     = "target.local"
}

variable "tags" {
  description = "Tags to apply to VMs (as notes)"
  type        = map(string)
  default = {
    Project     = "AD-Migration"
    Environment = "Demo"
    ManagedBy   = "Terraform"
    Tier        = "1"
    Author      = "Adrian Johnson"
  }
}

