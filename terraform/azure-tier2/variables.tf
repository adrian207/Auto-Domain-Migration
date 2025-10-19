variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "admigration"
}

variable "environment" {
  description = "Environment name (prod, staging)"
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "secondary_location" {
  description = "Secondary Azure region for geo-redundancy"
  type        = string
  default     = "westus"
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
}

variable "allowed_ip_ranges" {
  description = "List of IP ranges allowed to access bastion (CIDR notation)"
  type        = list(string)
}

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

variable "postgres_admin_password" {
  description = "Password for PostgreSQL admin user"
  type        = string
  sensitive   = true
}

variable "guacamole_db_password" {
  description = "Password for Guacamole PostgreSQL database"
  type        = string
  sensitive   = true
}

# =============================================================================
# High Availability Configuration
# =============================================================================

variable "enable_availability_zones" {
  description = "Deploy VMs across availability zones for HA"
  type        = bool
  default     = true
}

variable "num_ansible_controllers" {
  description = "Number of Ansible controller VMs (2-3 recommended for HA)"
  type        = number
  default     = 2

  validation {
    condition     = var.num_ansible_controllers >= 1 && var.num_ansible_controllers <= 5
    error_message = "Number of Ansible controllers must be between 1 and 5."
  }
}

variable "num_postgres_nodes" {
  description = "Number of PostgreSQL nodes for HA cluster (3 recommended for Patroni)"
  type        = number
  default     = 3

  validation {
    condition     = var.num_postgres_nodes >= 1 && var.num_postgres_nodes <= 5
    error_message = "Number of PostgreSQL nodes must be between 1 and 5."
  }
}

# =============================================================================
# VM SKUs (Production Sizing)
# =============================================================================

variable "guacamole_vm_size" {
  description = "VM size for Guacamole bastion"
  type        = string
  default     = "Standard_D2s_v5" # 2 vCPU, 8 GB RAM
}

variable "ansible_vm_size" {
  description = "VM size for Ansible controllers"
  type        = string
  default     = "Standard_D8s_v5" # 8 vCPU, 32 GB RAM (parallel execution)
}

variable "postgres_vm_size" {
  description = "VM size for PostgreSQL nodes"
  type        = string
  default     = "Standard_E4s_v5" # 4 vCPU, 32 GB RAM (memory optimized)
}

variable "dc_vm_size" {
  description = "VM size for domain controllers (optimized for ADMT endpoint)"
  type        = string
  default     = "Standard_B2s" # 2 vCPU, 4 GB RAM - optimized for DC role
}

variable "monitoring_vm_size" {
  description = "VM size for monitoring (Prometheus/Grafana)"
  type        = string
  default     = "Standard_D4s_v5" # 4 vCPU, 16 GB RAM
}

# =============================================================================
# Database Configuration
# =============================================================================

variable "postgres_sku_name" {
  description = "PostgreSQL Flexible Server SKU"
  type        = string
  default     = "GP_Standard_D4s_v3" # General Purpose, 4 vCPU, 16 GB RAM
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 131072 # 128 GB
}

variable "postgres_backup_retention_days" {
  description = "PostgreSQL backup retention in days"
  type        = number
  default     = 35 # Maximum for flexible server
}

variable "enable_postgres_ha" {
  description = "Enable PostgreSQL high availability (zone-redundant)"
  type        = bool
  default     = true
}

# =============================================================================
# Storage Configuration
# =============================================================================

variable "storage_account_tier" {
  description = "Storage account tier (Standard or Premium)"
  type        = string
  default     = "Standard"
}

variable "storage_account_replication" {
  description = "Storage account replication type"
  type        = string
  default     = "GRS" # Geo-redundant storage
}

# =============================================================================
# Monitoring and Logging
# =============================================================================

variable "enable_log_analytics" {
  description = "Enable Azure Log Analytics workspace"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 90
}

variable "enable_azure_monitor" {
  description = "Enable Azure Monitor alerts"
  type        = bool
  default     = true
}

variable "enable_application_insights" {
  description = "Enable Application Insights for telemetry"
  type        = bool
  default     = true
}

# =============================================================================
# Security Configuration
# =============================================================================

variable "enable_key_vault" {
  description = "Enable Azure Key Vault for secrets management"
  type        = bool
  default     = true
}

variable "enable_ddos_protection" {
  description = "Enable DDoS Protection Standard"
  type        = bool
  default     = false # Additional cost, enable if needed
}

variable "enable_nsg_flow_logs" {
  description = "Enable NSG flow logs"
  type        = bool
  default     = true
}

# =============================================================================
# Backup and DR
# =============================================================================

variable "enable_azure_backup" {
  description = "Enable Azure Backup for VMs"
  type        = bool
  default     = true
}

variable "backup_policy_timezone" {
  description = "Timezone for backup policy"
  type        = string
  default     = "UTC"
}

variable "backup_retention_days" {
  description = "VM backup retention in days"
  type        = number
  default     = 30
}

# =============================================================================
# Feature Flags
# =============================================================================

variable "enable_guacamole" {
  description = "Enable Apache Guacamole bastion host"
  type        = bool
  default     = true
}

variable "enable_monitoring_stack" {
  description = "Enable Prometheus/Grafana monitoring"
  type        = bool
  default     = true
}

variable "enable_auto_shutdown" {
  description = "Enable auto-shutdown for non-production VMs"
  type        = bool
  default     = false
}

# =============================================================================
# Container Apps Configuration
# =============================================================================

variable "ansible_container_image" {
  description = "Container image for Ansible controller"
  type        = string
  default     = "migration-controller:latest" # Build with: docker build -t <acr>.azurecr.io/migration-controller:latest && docker push
}

variable "auto_shutdown_time" {
  description = "Time to shut down VMs daily (24-hour format, e.g., '1900' for 7 PM)"
  type        = string
  default     = "1900"
}

variable "auto_shutdown_notification_enabled" {
  description = "Send notification before auto-shutdown"
  type        = bool
  default     = true
}

variable "auto_shutdown_notification_email" {
  description = "Email for auto-shutdown notifications"
  type        = string
  default     = "admin@example.com"
}

# =============================================================================
# Auto-healing and Scaling
# =============================================================================

variable "enable_auto_healing" {
  description = "Enable automatic VM health monitoring and repair"
  type        = bool
  default     = true
}

# =============================================================================
# Cost Management
# =============================================================================

variable "enable_cost_alerts" {
  description = "Enable cost management alerts"
  type        = bool
  default     = true
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD for cost alerts"
  type        = number
  default     = 2000
}

variable "cost_alert_emails" {
  description = "List of emails for cost alerts"
  type        = list(string)
  default     = ["admin@example.com"]
}

# =============================================================================
# Enhanced Security
# =============================================================================

variable "enable_defender_for_cloud" {
  description = "Enable Azure Defender for advanced threat protection"
  type        = bool
  default     = true
}

variable "enable_private_endpoints" {
  description = "Enable private endpoints for PaaS services"
  type        = bool
  default     = true
}

variable "enable_cmk_encryption" {
  description = "Enable Customer-Managed Keys for encryption"
  type        = bool
  default     = false # Requires additional setup
}

variable "enable_jit_access" {
  description = "Enable Just-In-Time VM access"
  type        = bool
  default     = true
}

variable "enable_azure_firewall" {
  description = "Enable Azure Firewall for advanced network security"
  type        = bool
  default     = false # Additional cost
}

variable "azure_firewall_tier" {
  description = "Azure Firewall tier (Standard or Premium)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.azure_firewall_tier)
    error_message = "Firewall tier must be 'Standard' or 'Premium'."
  }
}

# =============================================================================
# Performance Optimizations
# =============================================================================

variable "enable_postgres_read_replica" {
  description = "Enable PostgreSQL read replica in secondary region"
  type        = bool
  default     = false # Additional cost
}

variable "enable_redis_cache" {
  description = "Enable Azure Cache for Redis"
  type        = bool
  default     = false
}

variable "redis_cache_sku" {
  description = "Redis cache SKU (Basic, Standard, Premium)"
  type        = string
  default     = "Standard"
}

variable "redis_cache_family" {
  description = "Redis cache family (C for Basic/Standard, P for Premium)"
  type        = string
  default     = "C"
}

variable "redis_cache_capacity" {
  description = "Redis cache capacity (0-6 for Basic/Standard, 1-5 for Premium)"
  type        = number
  default     = 1
}

variable "redis_shard_count" {
  description = "Number of shards for Premium Redis (1-10)"
  type        = number
  default     = 2
}

variable "enable_cdn" {
  description = "Enable Azure CDN for static content"
  type        = bool
  default     = false
}

variable "enable_proximity_placement" {
  description = "Enable proximity placement group for low latency"
  type        = bool
  default     = false
}

variable "enable_premium_ssd_v2" {
  description = "Enable Premium SSD v2 for high IOPS workloads"
  type        = bool
  default     = false
}

variable "enable_frontdoor" {
  description = "Enable Azure Front Door for global acceleration"
  type        = bool
  default     = false
}

variable "frontdoor_sku" {
  description = "Azure Front Door SKU (Standard_AzureFrontDoor or Premium_AzureFrontDoor)"
  type        = string
  default     = "Standard_AzureFrontDoor"
}

variable "enable_performance_monitoring" {
  description = "Enable advanced performance monitoring and alerts"
  type        = bool
  default     = true
}

variable "performance_alert_email" {
  description = "Email for performance alerts"
  type        = string
  default     = "performance-team@example.com"
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "AD-Migration"
    Environment = "Production"
    ManagedBy   = "Terraform"
    Tier        = "2"
    CostCenter  = "IT"
    Compliance  = "Required"
  }
}

variable "use_vm_file_servers" {
  description = "Use VM-based file servers (true) or Azure Files (false, recommended)"
  type        = bool
  default     = false
}


