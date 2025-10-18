# AKS Cluster Configuration for Tier 3
# Purpose: Enterprise-grade Kubernetes cluster with full HA

# =============================================================================
# AKS Cluster
# =============================================================================

resource "azurerm_kubernetes_cluster" "main" {
  name                = "${local.resource_prefix}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${local.resource_prefix}-aks"
  kubernetes_version  = var.kubernetes_version

  # System node pool (for Kubernetes system components)
  default_node_pool {
    name            = "system"
    node_count      = var.system_node_pool_min_count
    vm_size         = var.system_node_pool_vm_size
    vnet_subnet_id  = azurerm_subnet.aks.id
    os_disk_size_gb = 128
    os_disk_type    = "Managed"
    
    # Only system pods on these nodes
    node_labels = {
      "role" = "system"
    }
    
    upgrade_settings {
      max_surge = "33%"
    }

    tags = merge(local.common_tags, {
      NodePool = "system"
    })
  }

  # Managed identity
  identity {
    type = "SystemAssigned"
  }

  # Network profile
  network_profile {
    network_plugin     = var.aks_network_plugin
    network_policy     = var.aks_network_policy
    load_balancer_sku  = "standard"
    outbound_type      = "loadBalancer"
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
    
    load_balancer_profile {
      managed_outbound_ip_count = 2
    }
  }

  # Azure AD integration
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = var.enable_azure_ad_rbac
    admin_group_object_ids = []  # Add Azure AD group IDs for cluster admins
  }

  # API server access profile
  dynamic "api_server_access_profile" {
    for_each = var.enable_private_cluster || length(var.authorized_ip_ranges) > 0 ? [1] : []
    content {
      authorized_ip_ranges = var.authorized_ip_ranges
    }
  }

  # Private cluster configuration
  private_cluster_enabled = var.enable_private_cluster

  # OMS Agent (Container Insights)
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # Key Vault Secrets Provider
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # Auto-scaler profile
  auto_scaler_profile {
    balance_similar_node_groups      = true
    expander                         = "random"
    max_graceful_termination_sec     = 600
    max_node_provisioning_time       = "15m"
    max_unready_nodes                = 3
    max_unready_percentage           = 45
    new_pod_scale_up_delay           = "10s"
    scale_down_delay_after_add       = "10m"
    scale_down_delay_after_delete    = "10s"
    scale_down_delay_after_failure   = "3m"
    scan_interval                    = "10s"
    scale_down_unneeded              = "10m"
    scale_down_unready               = "20m"
    scale_down_utilization_threshold = "0.5"
  }

  # Maintenance window
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [0, 1, 2, 3]
    }
  }

  tags = local.common_tags
}

# =============================================================================
# Worker Node Pool (for migration workloads)
# =============================================================================

resource "azurerm_kubernetes_cluster_node_pool" "workers" {
  name                  = "workers"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.worker_node_pool_vm_size
  node_count            = var.worker_node_pool_min_count
  vnet_subnet_id        = azurerm_subnet.aks.id
  os_disk_size_gb       = 256
  os_disk_type          = "Managed"
  
  # Labels for workload scheduling
  node_labels = {
    "role"     = "worker"
    "workload" = "migration"
  }
  
  upgrade_settings {
    max_surge = "33%"
  }
  
  tags = merge(local.common_tags, {
    NodePool = "workers"
  })
}

# =============================================================================
# AKS Role Assignments
# =============================================================================

# Assign AKS cluster identity to pull images from ACR (if needed)
resource "azurerm_role_assignment" "aks_acr_pull" {
  count                = 0  # Enable if using Azure Container Registry
  scope                = azurerm_resource_group.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# Assign AKS cluster identity to manage network resources
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_virtual_network.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

# Assign AKS cluster identity to Key Vault
resource "azurerm_key_vault_access_policy" "aks" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].object_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# =============================================================================
# Diagnostic Settings
# =============================================================================

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "${local.resource_prefix}-aks-diag"
  target_resource_id         = azurerm_kubernetes_cluster.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "cluster-autoscaler"
  }

  metric {
    category = "AllMetrics"
  }
}

# =============================================================================
# Alerts for AKS
# =============================================================================

resource "azurerm_monitor_metric_alert" "aks_node_cpu" {
  name                = "${local.resource_prefix}-aks-node-cpu-alert"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_kubernetes_cluster.main.id]
  description         = "Alert when AKS node CPU usage is high"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "aks_node_memory" {
  name                = "${local.resource_prefix}-aks-node-memory-alert"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_kubernetes_cluster.main.id]
  description         = "Alert when AKS node memory usage is high"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_memory_working_set_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "aks_pod_count" {
  name                = "${local.resource_prefix}-aks-pod-count-alert"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_kubernetes_cluster.main.id]
  description         = "Alert when AKS pod count is approaching limits"
  severity            = 3
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "kube_pod_status_ready"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 200
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}

