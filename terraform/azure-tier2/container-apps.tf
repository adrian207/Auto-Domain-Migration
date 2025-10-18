# Azure Container Apps - Tier 2 Optimized
# Purpose: Replace expensive VMs with container-based workloads

# =============================================================================
# CONTAINER APPS ENVIRONMENT
# =============================================================================

resource "azurerm_container_app_environment" "main" {
  name                = "${local.resource_prefix}-cae"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  # Use Consumption workload profile (pay per use)
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  # Integrate with Log Analytics
  log_analytics_workspace_id = var.enable_log_analytics ? azurerm_log_analytics_workspace.main[0].id : null

  tags = local.common_tags
}

# =============================================================================
# ANSIBLE CONTROLLER CONTAINER APP
# =============================================================================

resource "azurerm_container_app" "ansible" {
  name                         = "${local.resource_prefix}-ansible"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  template {
    container {
      name   = "ansible-controller"
      image  = var.ansible_container_image
      cpu    = 4
      memory = "8Gi"

      env {
        name  = "POSTGRES_HOST"
        value = azurerm_postgresql_flexible_server.main.fqdn
      }

      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "postgres-password"
      }

      env {
        name  = "AZURE_STORAGE_ACCOUNT"
        value = azurerm_storage_account.main.name
      }

      env {
        name        = "AZURE_STORAGE_KEY"
        secret_name = "storage-key"
      }

      volume_mounts {
        name = "ansible-data"
        path = "/opt/ansible/data"
      }
    }

    min_replicas = 1
    max_replicas = 3

    volume {
      name         = "ansible-data"
      storage_type = "AzureFile"
      storage_name = azurerm_storage_share.ansible.name
    }
  }

  secret {
    name  = "postgres-password"
    value = var.postgres_admin_password
  }

  secret {
    name  = "storage-key"
    value = azurerm_storage_account.main.primary_access_key
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(local.common_tags, { Role = "Ansible-Controller" })
}

# =============================================================================
# GUACAMOLE BASTION CONTAINER APP
# =============================================================================

resource "azurerm_container_app" "guacamole" {
  count                        = var.enable_guacamole ? 1 : 0
  name                         = "${local.resource_prefix}-guacamole"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  template {
    container {
      name   = "guacd"
      image  = "guacamole/guacd:latest"
      cpu    = 0.5
      memory = "1Gi"
    }

    container {
      name   = "guacamole"
      image  = "guacamole/guacamole:latest"
      cpu    = 1.5
      memory = "3Gi"

      env {
        name  = "GUACD_HOSTNAME"
        value = "localhost"
      }

      env {
        name  = "POSTGRES_HOSTNAME"
        value = azurerm_postgresql_flexible_server.main.fqdn
      }

      env {
        name  = "POSTGRES_DATABASE"
        value = azurerm_postgresql_flexible_server_database.guacamole.name
      }

      env {
        name  = "POSTGRES_USER"
        value = azurerm_postgresql_flexible_server.main.administrator_login
      }

      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "postgres-password"
      }
    }

    min_replicas = 1
    max_replicas = 2
  }

  ingress {
    external_enabled = true
    target_port      = 8080

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  secret {
    name  = "postgres-password"
    value = var.guacamole_db_password
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(local.common_tags, { Role = "Bastion" })
}

# =============================================================================
# PROMETHEUS MONITORING CONTAINER APP
# =============================================================================

resource "azurerm_container_app" "prometheus" {
  count                        = var.enable_monitoring_stack ? 1 : 0
  name                         = "${local.resource_prefix}-prometheus"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  template {
    container {
      name   = "prometheus"
      image  = "prom/prometheus:latest"
      cpu    = 2
      memory = "4Gi"

      volume_mounts {
        name = "prometheus-data"
        path = "/prometheus"
      }

      volume_mounts {
        name = "prometheus-config"
        path = "/etc/prometheus"
      }
    }

    min_replicas = 1
    max_replicas = 1 # Stateful, single instance

    volume {
      name         = "prometheus-data"
      storage_type = "AzureFile"
      storage_name = azurerm_storage_share.prometheus.name
    }

    volume {
      name         = "prometheus-config"
      storage_type = "AzureFile"
      storage_name = azurerm_storage_share.prometheus_config.name
    }
  }

  ingress {
    external_enabled = false # Internal only
    target_port      = 9090

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = merge(local.common_tags, { Role = "Monitoring" })
}

# =============================================================================
# GRAFANA DASHBOARD CONTAINER APP
# =============================================================================

resource "azurerm_container_app" "grafana" {
  count                        = var.enable_monitoring_stack ? 1 : 0
  name                         = "${local.resource_prefix}-grafana"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  template {
    container {
      name   = "grafana"
      image  = "grafana/grafana:latest"
      cpu    = 2
      memory = "4Gi"

      env {
        name  = "GF_DATABASE_TYPE"
        value = "postgres"
      }

      env {
        name  = "GF_DATABASE_HOST"
        value = "${azurerm_postgresql_flexible_server.main.fqdn}:5432"
      }

      env {
        name  = "GF_DATABASE_NAME"
        value = var.enable_monitoring_stack ? azurerm_postgresql_flexible_server_database.monitoring[0].name : ""
      }

      env {
        name  = "GF_DATABASE_USER"
        value = azurerm_postgresql_flexible_server.main.administrator_login
      }

      env {
        name        = "GF_DATABASE_PASSWORD"
        secret_name = "postgres-password"
      }

      env {
        name        = "GF_SECURITY_ADMIN_PASSWORD"
        secret_name = "grafana-admin-password"
      }

      volume_mounts {
        name = "grafana-data"
        path = "/var/lib/grafana"
      }
    }

    min_replicas = 1
    max_replicas = 2
  }

  ingress {
    external_enabled = true
    target_port      = 3000

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  secret {
    name  = "postgres-password"
    value = var.postgres_admin_password
  }

  secret {
    name  = "grafana-admin-password"
    value = var.admin_password
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(local.common_tags, { Role = "Monitoring" })
}

# =============================================================================
# STORAGE SHARES FOR CONTAINER APPS
# =============================================================================

resource "azurerm_storage_share" "ansible" {
  name               = "ansible-data"
  storage_account_id = azurerm_storage_account.main.id
  quota              = 10 # GB
}

resource "azurerm_storage_share" "prometheus" {
  name               = "prometheus-data"
  storage_account_id = azurerm_storage_account.main.id
  quota              = 50 # GB
}

resource "azurerm_storage_share" "prometheus_config" {
  name               = "prometheus-config"
  storage_account_id = azurerm_storage_account.main.id
  quota              = 1 # GB
}

resource "azurerm_storage_share" "grafana" {
  name               = "grafana-data"
  storage_account_id = azurerm_storage_account.main.id
  quota              = 10 # GB
}

