# PostgreSQL Flexible Server - Azure Tier 2 (Production)
# High Availability with zone-redundant configuration

# Private DNS Zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Link DNS zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${local.resource_prefix}-postgres-vnet-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.main.id

  tags = local.common_tags
}

# PostgreSQL Flexible Server (Production)
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${local.resource_prefix}-psql-${random_string.suffix.result}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "15"
  delegated_subnet_id    = azurerm_subnet.database.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres.id
  administrator_login    = var.admin_username
  administrator_password = var.postgres_admin_password
  zone                   = var.enable_postgres_ha ? null : (var.enable_availability_zones ? "1" : null)

  storage_mb   = var.postgres_storage_mb
  storage_tier = "P30" # Premium SSD tier

  sku_name = var.postgres_sku_name

  # High Availability Configuration
  high_availability {
    mode                      = var.enable_postgres_ha ? "ZoneRedundant" : "Disabled"
    standby_availability_zone = var.enable_postgres_ha ? "2" : null
  }

  # Backup Configuration
  backup_retention_days        = var.postgres_backup_retention_days
  geo_redundant_backup_enabled = true

  # Maintenance Window
  maintenance_window {
    day_of_week  = 0 # Sunday
    start_hour   = 2 # 2 AM
    start_minute = 0
  }

  # Security
  authentication {
    active_directory_auth_enabled = false
    password_auth_enabled         = true
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres
  ]

  tags = local.common_tags
}

# PostgreSQL Configuration - Performance Tuning
resource "azurerm_postgresql_flexible_server_configuration" "shared_buffers" {
  name      = "shared_buffers"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "8388608" # 8 GB (in 8KB pages)
}

resource "azurerm_postgresql_flexible_server_configuration" "effective_cache_size" {
  name      = "effective_cache_size"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "16777216" # 16 GB
}

resource "azurerm_postgresql_flexible_server_configuration" "work_mem" {
  name      = "work_mem"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "65536" # 64 MB
}

resource "azurerm_postgresql_flexible_server_configuration" "maintenance_work_mem" {
  name      = "maintenance_work_mem"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "524288" # 512 MB
}

resource "azurerm_postgresql_flexible_server_configuration" "max_connections" {
  name      = "max_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "500"
}

resource "azurerm_postgresql_flexible_server_configuration" "checkpoint_completion_target" {
  name      = "checkpoint_completion_target"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "0.9"
}

resource "azurerm_postgresql_flexible_server_configuration" "wal_buffers" {
  name      = "wal_buffers"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "2048" # 16 MB
}

resource "azurerm_postgresql_flexible_server_configuration" "random_page_cost" {
  name      = "random_page_cost"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "1.1" # SSD optimization
}

resource "azurerm_postgresql_flexible_server_configuration" "effective_io_concurrency" {
  name      = "effective_io_concurrency"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "200"
}

# Logging Configuration
resource "azurerm_postgresql_flexible_server_configuration" "log_checkpoints" {
  name      = "log_checkpoints"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_disconnections" {
  name      = "log_disconnections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_duration" {
  name      = "log_duration"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_min_duration_statement" {
  name      = "log_min_duration_statement"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "1000" # Log queries taking more than 1 second
}

# =============================================================================
# DATABASES
# =============================================================================

# Database for Guacamole
resource "azurerm_postgresql_flexible_server_database" "guacamole" {
  name      = "guacamole_db"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# Database for Migration State Store
resource "azurerm_postgresql_flexible_server_database" "statestore" {
  name      = "migration_state"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# Database for Telemetry
resource "azurerm_postgresql_flexible_server_database" "telemetry" {
  name      = "migration_telemetry"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# Database for AWX (Ansible Tower)
resource "azurerm_postgresql_flexible_server_database" "awx" {
  name      = "awx_db"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# Database for Monitoring (Grafana)
resource "azurerm_postgresql_flexible_server_database" "monitoring" {
  count     = var.enable_monitoring_stack ? 1 : 0
  name      = "grafana_db"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# =============================================================================
# FIREWALL RULES (Private Endpoint, so minimal rules)
# =============================================================================

# Allow Azure services (for management)
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "Allow-Azure-Services"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# =============================================================================
# DIAGNOSTIC SETTINGS (if Log Analytics enabled)
# =============================================================================

resource "azurerm_monitor_diagnostic_setting" "postgres" {
  count                      = var.enable_log_analytics ? 1 : 0
  name                       = "${local.resource_prefix}-postgres-diag"
  target_resource_id         = azurerm_postgresql_flexible_server.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  enabled_log {
    category = "PostgreSQLLogs"
  }

  # Metrics are automatically collected by Azure Monitor
  # enabled_metric block is deprecated in provider 3.x
}

# =============================================================================
# ALERTS (if Azure Monitor enabled)
# =============================================================================

# Action Group for alerts
resource "azurerm_monitor_action_group" "database_alerts" {
  count               = var.enable_azure_monitor ? 1 : 0
  name                = "${local.resource_prefix}-db-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "db-alerts"

  email_receiver {
    name                    = "Database-Admin"
    email_address           = var.auto_shutdown_notification_email # Use existing email variable
    use_common_alert_schema = true
  }

  tags = local.common_tags
}

# Alert: High CPU usage
resource "azurerm_monitor_metric_alert" "postgres_cpu" {
  count               = var.enable_azure_monitor ? 1 : 0
  name                = "${local.resource_prefix}-postgres-high-cpu"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_postgresql_flexible_server.main.id]
  description         = "Alert when PostgreSQL CPU exceeds 80%"
  severity            = 2

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.database_alerts[0].id
  }

  tags = local.common_tags
}

# Alert: High memory usage
resource "azurerm_monitor_metric_alert" "postgres_memory" {
  count               = var.enable_azure_monitor ? 1 : 0
  name                = "${local.resource_prefix}-postgres-high-memory"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_postgresql_flexible_server.main.id]
  description         = "Alert when PostgreSQL memory exceeds 85%"
  severity            = 2

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "memory_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.database_alerts[0].id
  }

  tags = local.common_tags
}

# Alert: Storage usage
resource "azurerm_monitor_metric_alert" "postgres_storage" {
  count               = var.enable_azure_monitor ? 1 : 0
  name                = "${local.resource_prefix}-postgres-high-storage"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_postgresql_flexible_server.main.id]
  description         = "Alert when PostgreSQL storage exceeds 85%"
  severity            = 1

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "storage_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.database_alerts[0].id
  }

  tags = local.common_tags
}

# Alert: Connection failures
resource "azurerm_monitor_metric_alert" "postgres_connections" {
  count               = var.enable_azure_monitor ? 1 : 0
  name                = "${local.resource_prefix}-postgres-connection-failures"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_postgresql_flexible_server.main.id]
  description         = "Alert when PostgreSQL has connection failures"
  severity            = 2

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "connections_failed"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action {
    action_group_id = azurerm_monitor_action_group.database_alerts[0].id
  }

  tags = local.common_tags
}


