# Main Terraform Configuration for Tier 3 (Enterprise Edition)
# Purpose: Core resource definitions

locals {
  resource_prefix = var.resource_prefix
  common_tags = merge(var.tags, {
    DeploymentTier = "Tier-3-Enterprise"
    ManagedBy      = "Terraform"
  })
}

# =============================================================================
# Resource Group
# =============================================================================

resource "azurerm_resource_group" "main" {
  name     = "${local.resource_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# =============================================================================
# Log Analytics Workspace
# =============================================================================

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.resource_prefix}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = var.log_analytics_workspace_sku
  retention_in_days   = var.log_retention_days

  tags = local.common_tags
}

# =============================================================================
# Application Insights
# =============================================================================

resource "azurerm_application_insights" "main" {
  name                = "${local.resource_prefix}-appinsights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "other"

  tags = local.common_tags
}

# =============================================================================
# Storage Account
# =============================================================================

resource "azurerm_storage_account" "main" {
  name                     = replace("${local.resource_prefix}storage", "-", "")
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication

  # Enable blob versioning for disaster recovery
  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  # Security settings
  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"

  tags = local.common_tags
}

# Blob containers
resource "azurerm_storage_container" "containers" {
  for_each          = toset(var.blob_container_names)
  name              = each.value
  storage_account_id = azurerm_storage_account.main.id
}

# =============================================================================
# Key Vault
# =============================================================================

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                       = "${local.resource_prefix}-kv"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = var.key_vault_sku
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = true

  # Network rules for security
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    # Add specific IP ranges if needed
    ip_rules = var.authorized_ip_ranges
    
    # Allow access from AKS subnet
    virtual_network_subnet_ids = [
      azurerm_subnet.aks.id
    ]
  }

  tags = local.common_tags
}

# Key Vault access policy for current user/service principal
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get", "List", "Create", "Delete", "Update", "Recover", "Purge", "GetRotationPolicy"
  ]

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Purge"
  ]

  certificate_permissions = [
    "Get", "List", "Create", "Delete", "Update", "Import"
  ]
}

# Store admin password in Key Vault
resource "azurerm_key_vault_secret" "admin_password" {
  name         = "admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [
    azurerm_key_vault_access_policy.terraform
  ]
}

# Generate random password for AWX admin
resource "random_password" "awx_admin" {
  length  = 24
  special = true
}

resource "azurerm_key_vault_secret" "awx_admin_password" {
  name         = "awx-admin-password"
  value        = random_password.awx_admin.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [
    azurerm_key_vault_access_policy.terraform
  ]
}

# =============================================================================
# Cost Management
# =============================================================================

resource "azurerm_consumption_budget_resource_group" "main" {
  count = var.enable_cost_alerts ? 1 : 0

  name              = "${local.resource_prefix}-budget"
  resource_group_id = azurerm_resource_group.main.id

  amount     = var.monthly_budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  notification {
    enabled   = true
    threshold = var.budget_alert_threshold
    operator  = "GreaterThan"

    contact_emails = [
      "admin@example.com"  # Update with actual email
    ]
  }
}

# =============================================================================
# Azure Monitor Action Group
# =============================================================================

resource "azurerm_monitor_action_group" "main" {
  name                = "${local.resource_prefix}-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "tier3-alert"

  email_receiver {
    name                    = "Admin-Email"
    email_address           = "admin@example.com"  # Update with actual email
    use_common_alert_schema = true
  }

  webhook_receiver {
    name                    = "AWX-Webhook"
    service_uri             = "https://awx.migration.example.com/api/v2/job_templates/1/launch/"
    use_common_alert_schema = true
  }

  tags = local.common_tags
}

# =============================================================================
# Diagnostic Settings
# =============================================================================

resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "${local.resource_prefix}-storage-diag"
  target_resource_id         = azurerm_storage_account.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }
}

