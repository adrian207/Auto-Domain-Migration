# Azure Tier 2 (Production) Implementation
# Author: Adrian Johnson <adrian207@gmail.com>
# Purpose: Deploy production-scale AD migration environment with HA

locals {
  resource_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    var.tags,
    {
      DeployedBy = "Terraform"
      Author     = "Adrian Johnson"
      Timestamp  = timestamp()
    }
  )

  # Availability zones (if enabled)
  availability_zones = var.enable_availability_zones ? ["1", "2", "3"] : []
}

# Random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# =============================================================================
# RESOURCE GROUP
# =============================================================================

resource "azurerm_resource_group" "main" {
  name     = "${local.resource_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# Secondary resource group for DR (if using geo-redundancy)
resource "azurerm_resource_group" "secondary" {
  count    = var.storage_account_replication == "GRS" ? 1 : 0
  name     = "${local.resource_prefix}-dr-rg"
  location = var.secondary_location
  tags     = merge(local.common_tags, { Purpose = "Disaster-Recovery" })
}

# =============================================================================
# KEY VAULT (Secrets Management)
# =============================================================================

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  count                      = var.enable_key_vault ? 1 : 0
  name                       = "${var.project_name}-kv-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
    ]
  }

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = local.common_tags
}

# Store admin password in Key Vault
resource "azurerm_key_vault_secret" "admin_password" {
  count        = var.enable_key_vault ? 1 : 0
  name         = "admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.main[0].id

  tags = local.common_tags
}

# Store PostgreSQL password in Key Vault
resource "azurerm_key_vault_secret" "postgres_password" {
  count        = var.enable_key_vault ? 1 : 0
  name         = "postgres-admin-password"
  value        = var.postgres_admin_password
  key_vault_id = azurerm_key_vault.main[0].id

  tags = local.common_tags
}

# =============================================================================
# STORAGE ACCOUNT (Migration Artifacts)
# =============================================================================

resource "azurerm_storage_account" "main" {
  name                     = "${var.project_name}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication

  # Security features
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  # Advanced threat protection
  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  tags = local.common_tags
}

# Storage Container for migration artifacts
resource "azurerm_storage_container" "artifacts" {
  name                  = "migration-artifacts"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# Storage Container for USMT backups
resource "azurerm_storage_container" "usmt" {
  name                  = "usmt-backups"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# Storage Container for logs and diagnostics
resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# Storage Container for backups
resource "azurerm_storage_container" "backups" {
  name                  = "backups"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# =============================================================================
# LOG ANALYTICS WORKSPACE
# =============================================================================

resource "azurerm_log_analytics_workspace" "main" {
  count               = var.enable_log_analytics ? 1 : 0
  name                = "${local.resource_prefix}-law"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = local.common_tags
}

# =============================================================================
# APPLICATION INSIGHTS (Telemetry)
# =============================================================================

resource "azurerm_application_insights" "main" {
  count               = var.enable_application_insights ? 1 : 0
  name                = "${local.resource_prefix}-appi"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  application_type    = "other"
  workspace_id        = var.enable_log_analytics ? azurerm_log_analytics_workspace.main[0].id : null

  tags = local.common_tags
}

# =============================================================================
# RECOVERY SERVICES VAULT (Backup)
# =============================================================================

resource "azurerm_recovery_services_vault" "main" {
  count               = var.enable_azure_backup ? 1 : 0
  name                = "${local.resource_prefix}-rsv"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  soft_delete_enabled = true

  tags = local.common_tags
}

# Backup Policy for VMs
resource "azurerm_backup_policy_vm" "daily" {
  count               = var.enable_azure_backup ? 1 : 0
  name                = "${local.resource_prefix}-backup-policy"
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main[0].name

  timezone = var.backup_policy_timezone

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = var.backup_retention_days
  }

  retention_weekly {
    count    = 12
    weekdays = ["Sunday"]
  }

  retention_monthly {
    count    = 12
    weekdays = ["Sunday"]
    weeks    = ["First"]
  }
}


