# Azure Free Tier Implementation - Tier 1 (Demo)
# Author: Adrian Johnson <adrian207@gmail.com>
# Purpose: Deploy zero-cost demo environment for AD migration solution

locals {
  resource_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    var.tags,
    {
      DeployedBy = "Terraform"
      Author     = "Adrian Johnson"
    }
  )
}

# Random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${local.resource_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# Storage Account for diagnostics and artifacts (Free tier includes 5GB)
resource "azurerm_storage_account" "main" {
  name                     = "${var.project_name}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.common_tags
}

# Storage Container for migration artifacts
resource "azurerm_storage_container" "artifacts" {
  name                  = "migration-artifacts"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Storage Container for USMT backups
resource "azurerm_storage_container" "usmt" {
  name                  = "usmt-backups"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# =============================================================================
# AZURE KEY VAULT (Free tier: 10,000 operations/month)
# =============================================================================

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                       = "${var.project_name}-kv-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard" # FREE: 10,000 operations/month
  soft_delete_retention_days = 7          # Minimum for free tier
  purge_protection_enabled   = false      # Can't enable for free/dev environments

  # Allow access from VMs
  network_acls {
    default_action = "Allow" # Less restrictive for demo/free tier
    bypass         = "AzureServices"
  }

  # Grant deployer full access
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
    ]

    key_permissions = [
      "Get", "List", "Create", "Delete"
    ]
  }

  tags = local.common_tags
}

# Store admin password in Key Vault
resource "azurerm_key_vault_secret" "admin_password" {
  name         = "admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.main.id

  tags = local.common_tags
}

# Store PostgreSQL password in Key Vault
resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-admin-password"
  value        = var.guacamole_db_password
  key_vault_id = azurerm_key_vault.main.id

  tags = local.common_tags
}

# Grant Guacamole VM access to Key Vault
resource "azurerm_key_vault_access_policy" "guacamole" {
  count        = var.enable_guacamole ? 1 : 0
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.guacamole[0].identity[0].principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}

# Grant Ansible VM access to Key Vault
resource "azurerm_key_vault_access_policy" "ansible" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.ansible.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}

