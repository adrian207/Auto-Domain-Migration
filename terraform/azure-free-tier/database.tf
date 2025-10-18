# PostgreSQL Flexible Server for State Store and Guacamole
# Using Burstable B1ms (included in free tier: 750 hours/month)

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${local.resource_prefix}-psql-${random_string.suffix.result}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "15"
  administrator_login    = var.admin_username
  administrator_password = var.guacamole_db_password

  storage_mb = 32768 # 32GB

  sku_name = "B_Standard_B1ms" # Burstable tier - FREE (750 hours/month)

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  tags = local.common_tags
}

# Firewall rule to allow Azure services
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "Allow-Azure-Services"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Firewall rule to allow access from VNet
resource "azurerm_postgresql_flexible_server_firewall_rule" "vnet" {
  name             = "Allow-VNet"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "10.0.0.0"
  end_ip_address   = "10.0.255.255"
}

# Database for Guacamole
resource "azurerm_postgresql_flexible_server_database" "guacamole" {
  name      = "guacamole_db"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Database for Migration State Store
resource "azurerm_postgresql_flexible_server_database" "statestore" {
  name      = "migration_state"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Database for Telemetry
resource "azurerm_postgresql_flexible_server_database" "telemetry" {
  name      = "migration_telemetry"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

