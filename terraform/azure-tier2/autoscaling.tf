# Auto-scaling and Auto-shutdown - Azure Tier 2 Optimizations
# Purpose: Reduce costs through intelligent scaling and scheduling

# =============================================================================
# AUTO-SHUTDOWN SCHEDULES (Dev/Test environments)
# =============================================================================

resource "azurerm_dev_test_global_vm_shutdown_schedule" "ansible" {
  count              = var.enable_auto_shutdown ? var.num_ansible_controllers : 0
  virtual_machine_id = azurerm_linux_virtual_machine.ansible[count.index].id
  location           = azurerm_resource_group.main.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.backup_policy_timezone

  notification_settings {
    enabled         = var.auto_shutdown_notification_enabled
    time_in_minutes = 30
    email           = var.auto_shutdown_notification_email
  }

  tags = local.common_tags
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "monitoring" {
  count              = var.enable_monitoring_stack && var.enable_auto_shutdown ? 1 : 0
  virtual_machine_id = azurerm_linux_virtual_machine.monitoring[0].id
  location           = azurerm_resource_group.main.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.backup_policy_timezone

  notification_settings {
    enabled         = var.auto_shutdown_notification_enabled
    time_in_minutes = 30
    email           = var.auto_shutdown_notification_email
  }

  tags = local.common_tags
}

# Don't auto-shutdown domain controllers or bastion in production
resource "azurerm_dev_test_global_vm_shutdown_schedule" "guacamole" {
  count              = var.enable_guacamole && var.enable_auto_shutdown && var.environment != "prod" ? 1 : 0
  virtual_machine_id = azurerm_linux_virtual_machine.guacamole[0].id
  location           = azurerm_resource_group.main.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.backup_policy_timezone

  notification_settings {
    enabled         = var.auto_shutdown_notification_enabled
    time_in_minutes = 30
    email           = var.auto_shutdown_notification_email
  }

  tags = local.common_tags
}

# =============================================================================
# VM APPLICATION HEALTH EXTENSION (Auto-healing)
# =============================================================================

resource "azurerm_virtual_machine_extension" "ansible_health" {
  count                      = var.enable_auto_healing ? var.num_ansible_controllers : 0
  name                       = "ApplicationHealthExtension"
  virtual_machine_id         = azurerm_linux_virtual_machine.ansible[count.index].id
  publisher                  = "Microsoft.ManagedServices"
  type                       = "ApplicationHealthLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    protocol    = "tcp"
    port        = 22
    requestPath = ""
  })

  tags = local.common_tags
}

# =============================================================================
# VMSS AUTO-SCALE RULES (For future VMSS migration)
# =============================================================================

# Placeholder for future migration to VMSS with auto-scaling
# This will be used when upgrading to Tier 3 or implementing dynamic scaling

# =============================================================================
# COST MANAGEMENT ALERTS
# =============================================================================

resource "azurerm_consumption_budget_resource_group" "main" {
  count             = var.enable_cost_alerts ? 1 : 0
  name              = "${local.resource_prefix}-budget"
  resource_group_id = azurerm_resource_group.main.id

  amount     = var.monthly_budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  notification {
    enabled   = true
    threshold = 80.0
    operator  = "GreaterThan"

    contact_emails = var.cost_alert_emails
  }

  notification {
    enabled   = true
    threshold = 100.0
    operator  = "GreaterThan"

    contact_emails = var.cost_alert_emails
  }

  notification {
    enabled   = true
    threshold = 120.0
    operator  = "GreaterThan"

    contact_emails = var.cost_alert_emails
  }
}

# =============================================================================
# STORAGE LIFECYCLE MANAGEMENT (Cost Optimization)
# =============================================================================

resource "azurerm_storage_management_policy" "main" {
  storage_account_id = azurerm_storage_account.main.id

  # Archive old USMT backups after 90 days
  rule {
    name    = "archive-old-usmt-backups"
    enabled = true
    filters {
      prefix_match = ["usmt-backups/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than          = 365
      }
      snapshot {
        delete_after_days_since_creation_greater_than = 90
      }
    }
  }

  # Delete old logs after 90 days
  rule {
    name    = "delete-old-logs"
    enabled = true
    filters {
      prefix_match = ["logs/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 7
        delete_after_days_since_modification_greater_than       = 90
      }
    }
  }

  # Archive artifacts after 180 days
  rule {
    name    = "archive-old-artifacts"
    enabled = true
    filters {
      prefix_match = ["migration-artifacts/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        tier_to_archive_after_days_since_modification_greater_than = 180
      }
    }
  }
}

