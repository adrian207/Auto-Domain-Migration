# Terraform Variables for Tier 3 (Enterprise Edition)
# Purpose: Large-scale migration (>3,000 users) with full HA

# =============================================================================
# Core Configuration
# =============================================================================

variable "resource_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "migration-tier3"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (production, staging, etc.)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "ad-migration-enterprise"
}

# =============================================================================
# AKS Cluster Configuration
# =============================================================================

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.28.3"
}

variable "system_node_pool_vm_size" {
  description = "VM size for system node pool"
  type        = string
  default     = "Standard_D4s_v5" # 4 vCPU, 16GB RAM
}

variable "system_node_pool_min_count" {
  description = "Minimum number of nodes in system pool"
  type        = number
  default     = 3
}

variable "system_node_pool_max_count" {
  description = "Maximum number of nodes in system pool"
  type        = number
  default     = 5
}

variable "worker_node_pool_vm_size" {
  description = "VM size for worker node pool"
  type        = string
  default     = "Standard_D8s_v5" # 8 vCPU, 32GB RAM
}

variable "worker_node_pool_min_count" {
  description = "Minimum number of nodes in worker pool"
  type        = number
  default     = 6
}

variable "worker_node_pool_max_count" {
  description = "Maximum number of nodes in worker pool"
  type        = number
  default     = 12
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for node pools"
  type        = bool
  default     = true
}

variable "aks_network_plugin" {
  description = "Network plugin for AKS (azure or kubenet)"
  type        = string
  default     = "azure"
}

variable "aks_network_policy" {
  description = "Network policy plugin (calico or azure)"
  type        = string
  default     = "calico"
}

# =============================================================================
# Networking Configuration
# =============================================================================

variable "vnet_address_space" {
  description = "Address space for virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_address_prefix" {
  description = "Address prefix for AKS subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "appgw_subnet_address_prefix" {
  description = "Address prefix for Application Gateway subnet"
  type        = string
  default     = "10.0.16.0/24"
}

variable "services_subnet_address_prefix" {
  description = "Address prefix for additional services subnet"
  type        = string
  default     = "10.0.32.0/24"
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services"
  type        = string
  default     = "10.100.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service"
  type        = string
  default     = "10.100.0.10"
}

# =============================================================================
# Storage Configuration
# =============================================================================

variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "storage_account_replication" {
  description = "Storage account replication type"
  type        = string
  default     = "GRS" # Geo-redundant for enterprise
}

variable "blob_container_names" {
  description = "Blob container names to create"
  type        = list(string)
  default = [
    "migration-artifacts",
    "usmt-backups",
    "logs",
    "state-files",
    "terraform-state"
  ]
}

# =============================================================================
# Security Configuration
# =============================================================================

variable "enable_azure_ad_rbac" {
  description = "Enable Azure AD RBAC for AKS"
  type        = bool
  default     = true
}

variable "enable_private_cluster" {
  description = "Enable private cluster (API server not publicly accessible)"
  type        = bool
  default     = false # Set to true for maximum security
}

variable "authorized_ip_ranges" {
  description = "Authorized IP ranges for API server access"
  type        = list(string)
  default     = [] # Empty allows all; restrict in production
}

variable "key_vault_sku" {
  description = "Key Vault SKU (standard or premium)"
  type        = string
  default     = "premium"
}

variable "enable_soft_delete" {
  description = "Enable soft delete for Key Vault"
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Soft delete retention period in days"
  type        = number
  default     = 90
}

# =============================================================================
# Monitoring Configuration
# =============================================================================

variable "log_analytics_workspace_sku" {
  description = "SKU for Log Analytics workspace"
  type        = string
  default     = "PerGB2018"
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 90
}

variable "enable_container_insights" {
  description = "Enable Container Insights for AKS"
  type        = bool
  default     = true
}

variable "enable_prometheus" {
  description = "Deploy Prometheus Operator"
  type        = bool
  default     = true
}

variable "enable_loki" {
  description = "Deploy Loki for log aggregation"
  type        = bool
  default     = true
}

variable "enable_jaeger" {
  description = "Deploy Jaeger for distributed tracing"
  type        = bool
  default     = true
}

# =============================================================================
# Application Configuration
# =============================================================================

variable "deploy_awx" {
  description = "Deploy AWX using Helm"
  type        = bool
  default     = true
}

variable "awx_replicas" {
  description = "Number of AWX replicas"
  type        = number
  default     = 3
}

variable "deploy_vault" {
  description = "Deploy HashiCorp Vault"
  type        = bool
  default     = true
}

variable "vault_replicas" {
  description = "Number of Vault replicas"
  type        = number
  default     = 3
}

variable "deploy_minio" {
  description = "Deploy MinIO for object storage"
  type        = bool
  default     = true
}

variable "minio_replicas" {
  description = "Number of MinIO replicas"
  type        = number
  default     = 6
}

# =============================================================================
# Domain Controller Configuration
# =============================================================================

variable "deploy_target_dc" {
  description = "Deploy target domain controller VM"
  type        = bool
  default     = true
}

variable "target_dc_vm_size" {
  description = "VM size for target domain controller"
  type        = string
  default     = "Standard_B2s" # 2 vCPU, 4GB RAM
}

variable "source_domain_fqdn" {
  description = "Source domain FQDN"
  type        = string
  default     = "source.local"
}

variable "target_domain_fqdn" {
  description = "Target domain FQDN"
  type        = string
  default     = "target.local"
}

variable "admin_username" {
  description = "Administrator username for VMs"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Administrator password for VMs"
  type        = string
  sensitive   = true
}

# =============================================================================
# Backup and Disaster Recovery
# =============================================================================

variable "enable_backup" {
  description = "Enable Azure Backup for VMs"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 30
}

variable "enable_geo_replication" {
  description = "Enable geo-replication for storage"
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
  description = "Monthly budget amount in USD"
  type        = number
  default     = 6000
}

variable "budget_alert_threshold" {
  description = "Budget alert threshold percentage"
  type        = number
  default     = 80
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default = {
    Project     = "AD-Migration"
    Environment = "Production"
    ManagedBy   = "Terraform"
    Tier        = "3"
    CostCenter  = "IT"
    Compliance  = "Required"
  }
}

