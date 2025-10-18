variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "admigration"
}

variable "environment" {
  description = "Environment name (demo, dev, prod)"
  type        = string
  default     = "demo"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Admin password for VMs (min 12 chars, must include uppercase, lowercase, number, and special char)"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for Linux VMs"
  type        = string
  default     = ""
}

variable "allowed_ip_ranges" {
  description = "List of IP ranges allowed to access resources (CIDR notation)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Change this to your IP for security
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

variable "guacamole_db_password" {
  description = "Password for Guacamole PostgreSQL database"
  type        = string
  sensitive   = true
}

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

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "AD-Migration"
    Environment = "Demo"
    ManagedBy   = "Terraform"
    Tier        = "1"
  }
}

