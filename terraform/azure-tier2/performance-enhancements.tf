# Performance Enhancements - Azure Tier 2 Optimizations
# Purpose: Improve performance and reduce latency

# =============================================================================
# POSTGRESQL READ REPLICAS (Performance & HA)
# =============================================================================

# Read replica for read-heavy workloads
resource "azurerm_postgresql_flexible_server" "read_replica" {
  count               = var.enable_postgres_read_replica ? 1 : 0
  name                = "${local.resource_prefix}-psql-replica-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.secondary_location # Deploy in secondary region
  version             = "15"
  create_mode         = "Replica"
  source_server_id    = azurerm_postgresql_flexible_server.main.id

  storage_mb   = var.postgres_storage_mb
  storage_tier = "P30"

  sku_name = var.postgres_sku_name

  tags = merge(local.common_tags, { Role = "ReadReplica" })
}

# =============================================================================
# AZURE CACHE FOR REDIS (Performance)
# =============================================================================

resource "azurerm_redis_cache" "main" {
  count                = var.enable_redis_cache ? 1 : 0
  name                 = "${var.project_name}-redis-${random_string.suffix.result}"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  capacity             = var.redis_cache_capacity
  family               = var.redis_cache_family
  sku_name             = var.redis_cache_sku
  non_ssl_port_enabled = false
  minimum_tls_version  = "1.2"

  # Premium tier features
  shard_count = var.redis_cache_sku == "Premium" ? var.redis_shard_count : null
  zones       = var.redis_cache_sku == "Premium" && var.enable_availability_zones ? ["1", "2", "3"] : null

  redis_configuration {
    authentication_enabled        = true
    maxmemory_reserved            = var.redis_cache_capacity * 50 # MB
    maxmemory_delta               = var.redis_cache_capacity * 50 # MB
    maxmemory_policy              = "allkeys-lru"
    notify_keyspace_events        = ""
    rdb_backup_enabled            = var.redis_cache_sku == "Premium" ? true : false
    rdb_backup_frequency          = var.redis_cache_sku == "Premium" ? 60 : null
    rdb_backup_max_snapshot_count = var.redis_cache_sku == "Premium" ? 1 : null
    rdb_storage_connection_string = var.redis_cache_sku == "Premium" ? azurerm_storage_account.main.primary_connection_string : null
  }

  tags = local.common_tags
}

# Store Redis connection string in Key Vault
resource "azurerm_key_vault_secret" "redis_connection" {
  count        = var.enable_redis_cache && var.enable_key_vault ? 1 : 0
  name         = "redis-connection-string"
  value        = azurerm_redis_cache.main[0].primary_connection_string
  key_vault_id = azurerm_key_vault.main[0].id

  tags = local.common_tags
}

# =============================================================================
# AZURE CDN (Optional, for static content delivery)
# =============================================================================

resource "azurerm_cdn_profile" "main" {
  count               = var.enable_cdn ? 1 : 0
  name                = "${local.resource_prefix}-cdn"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard_Microsoft"

  tags = local.common_tags
}

resource "azurerm_cdn_endpoint" "storage" {
  count               = var.enable_cdn ? 1 : 0
  name                = "${var.project_name}-cdn-${random_string.suffix.result}"
  profile_name        = azurerm_cdn_profile.main[0].name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  origin {
    name      = "storage-origin"
    host_name = azurerm_storage_account.main.primary_blob_host
  }

  is_compression_enabled = true
  content_types_to_compress = [
    "application/javascript",
    "application/json",
    "application/xml",
    "text/css",
    "text/html",
    "text/javascript",
    "text/plain",
  ]

  optimization_type = "GeneralWebDelivery"

  tags = local.common_tags
}

# =============================================================================
# ACCELERATED NETWORKING (Already enabled in VMs)
# =============================================================================
# Note: Accelerated Networking is enabled by default on supported VM sizes
# in Azure (D-series v3+, E-series v3+, etc.)

# =============================================================================
# PROXIMITY PLACEMENT GROUP (Reduce latency between VMs)
# =============================================================================

resource "azurerm_proximity_placement_group" "main" {
  count               = var.enable_proximity_placement ? 1 : 0
  name                = "${local.resource_prefix}-ppg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Note: To use PPG, add proximity_placement_group_id to VM configurations

# =============================================================================
# PREMIUM SSD V2 DISKS (Optional, for high-performance workloads)
# =============================================================================

# Managed disk for high-IOPS workloads
resource "azurerm_managed_disk" "high_perf" {
  count                = var.enable_premium_ssd_v2 ? var.num_ansible_controllers : 0
  name                 = "${local.resource_prefix}-ansible-${count.index + 1}-data-disk"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "PremiumV2_LRS"
  create_option        = "Empty"
  disk_size_gb         = 512

  # Premium SSD v2 specific settings
  disk_iops_read_write = 5000 # Configurable IOPS
  disk_mbps_read_write = 200  # Configurable throughput

  zone = var.enable_availability_zones ? local.availability_zones[count.index % length(local.availability_zones)] : null

  tags = local.common_tags
}

# Attach data disks to Ansible controllers
resource "azurerm_virtual_machine_data_disk_attachment" "ansible_data" {
  count              = var.enable_premium_ssd_v2 ? var.num_ansible_controllers : 0
  managed_disk_id    = azurerm_managed_disk.high_perf[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.ansible[count.index].id
  lun                = "10"
  caching            = "ReadWrite"
}

# =============================================================================
# AZURE FRONT DOOR (Global load balancing and acceleration)
# =============================================================================

resource "azurerm_cdn_frontdoor_profile" "main" {
  count               = var.enable_frontdoor ? 1 : 0
  name                = "${local.resource_prefix}-frontdoor"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = var.frontdoor_sku

  tags = local.common_tags
}

# Front Door Endpoint for Guacamole
resource "azurerm_cdn_frontdoor_endpoint" "guacamole" {
  count                    = var.enable_frontdoor && var.enable_guacamole ? 1 : 0
  name                     = "${var.project_name}-guac-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main[0].id

  tags = local.common_tags
}

# =============================================================================
# ENHANCED MONITORING - APPLICATION PERFORMANCE
# =============================================================================

# Application Performance Monitoring baseline
resource "azurerm_monitor_action_group" "performance" {
  count               = var.enable_performance_monitoring ? 1 : 0
  name                = "${local.resource_prefix}-perf-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "perf"

  email_receiver {
    name                    = "Performance-Team"
    email_address           = var.performance_alert_email
    use_common_alert_schema = true
  }

  tags = local.common_tags
}

# Alert: High VM CPU
resource "azurerm_monitor_metric_alert" "vm_cpu" {
  count               = var.enable_performance_monitoring ? var.num_ansible_controllers : 0
  name                = "${local.resource_prefix}-ansible-${count.index + 1}-high-cpu"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_virtual_machine.ansible[count.index].id]
  description         = "Alert when VM CPU exceeds 85%"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.performance[0].id
  }

  tags = local.common_tags
}

# Alert: High disk latency
resource "azurerm_monitor_metric_alert" "vm_disk_latency" {
  count               = var.enable_performance_monitoring ? var.num_ansible_controllers : 0
  name                = "${local.resource_prefix}-ansible-${count.index + 1}-disk-latency"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_virtual_machine.ansible[count.index].id]
  description         = "Alert when disk read latency exceeds 30ms"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "OS Disk Read Latency"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 30
  }

  action {
    action_group_id = azurerm_monitor_action_group.performance[0].id
  }

  tags = local.common_tags
}

