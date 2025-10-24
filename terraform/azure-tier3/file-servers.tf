# File Servers Configuration for Tier 3 (Enterprise)
# Purpose: Enterprise-scale file migration with Azure File Sync

# =============================================================================
# Azure File Sync Infrastructure (Recommended for Tier 3)
# =============================================================================

resource "azurerm_storage_account" "file_sync_storage" {
  name                     = "${var.resource_prefix}filesync"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "GRS" # Geo-redundant for enterprise
  account_kind             = "StorageV2"

  network_rules {
    default_action = "Deny"
    virtual_network_subnet_ids = [
      azurerm_subnet.services.id
    ]
    bypass = ["AzureServices"]
  }

  tags = local.common_tags
}

# Azure File Shares for each department
resource "azurerm_storage_share" "department_shares" {
  for_each = toset(["hr", "finance", "engineering", "sales", "marketing", "it"])

  name                 = each.key
  storage_account_name = azurerm_storage_account.file_sync_storage.name
  quota                = 2048 # 2TB per share
  enabled_protocol     = "SMB"
}

# Storage Sync Service
resource "azurerm_storage_sync" "main" {
  name                = "${var.resource_prefix}-sync"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = local.common_tags
}

# Sync Groups for each department
resource "azurerm_storage_sync_group" "department_sync" {
  for_each = toset(["hr", "finance", "engineering", "sales", "marketing", "it"])

  name            = "${each.key}-sync-group"
  storage_sync_id = azurerm_storage_sync.main.id
}

# Cloud Endpoints (Azure Files)
resource "azurerm_storage_sync_cloud_endpoint" "department_cloud" {
  for_each = toset(["hr", "finance", "engineering", "sales", "marketing", "it"])

  name                  = "${each.key}-cloud-endpoint"
  storage_sync_group_id = azurerm_storage_sync_group.department_sync[each.key].id
  file_share_name       = azurerm_storage_share.department_shares[each.key].name
  storage_account_id    = azurerm_storage_account.file_sync_storage.id
}

# =============================================================================
# Source File Server Cluster (On-Premises Simulation)
# =============================================================================

resource "azurerm_windows_virtual_machine" "source_fileserver" {
  count               = 2 # 2-node cluster
  name                = "${var.resource_prefix}-src-fs-${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_D8s_v5" # 8 vCPU, 32GB RAM
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  zone                = tostring(count.index + 1) # Availability zones

  network_interface_ids = [
    azurerm_network_interface.source_fileserver[count.index].id
  ]

  os_disk {
    name                 = "${var.resource_prefix}-src-fs-${count.index + 1}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 256
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  boot_diagnostics {}

  tags = merge(local.common_tags, {
    Role = "Source-FileServer-Node-${count.index + 1}"
  })
}

resource "azurerm_managed_disk" "source_fileserver_data" {
  count                = 2
  name                 = "${var.resource_prefix}-src-fs-${count.index + 1}-data"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 4096 # 4TB per node
  zone                 = tostring(count.index + 1)

  tags = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "source_fileserver_data" {
  count              = 2
  managed_disk_id    = azurerm_managed_disk.source_fileserver_data[count.index].id
  virtual_machine_id = azurerm_windows_virtual_machine.source_fileserver[count.index].id
  lun                = 0
  caching            = "ReadWrite"
}

resource "azurerm_network_interface" "source_fileserver" {
  count               = 2
  name                = "${var.resource_prefix}-src-fs-${count.index + 1}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.services.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.services.address_prefixes[0], 20 + count.index)
  }

  tags = local.common_tags
}

# =============================================================================
# Target File Server Cluster (New Environment)
# =============================================================================

resource "azurerm_windows_virtual_machine" "target_fileserver" {
  count               = 2 # 2-node cluster
  name                = "${var.resource_prefix}-tgt-fs-${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_D8s_v5" # 8 vCPU, 32GB RAM
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  zone                = tostring(count.index + 1) # Availability zones

  network_interface_ids = [
    azurerm_network_interface.target_fileserver[count.index].id
  ]

  os_disk {
    name                 = "${var.resource_prefix}-tgt-fs-${count.index + 1}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 256
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  boot_diagnostics {}

  tags = merge(local.common_tags, {
    Role = "Target-FileServer-Node-${count.index + 1}"
  })
}

resource "azurerm_managed_disk" "target_fileserver_data" {
  count                = 2
  name                 = "${var.resource_prefix}-tgt-fs-${count.index + 1}-data"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 4096 # 4TB per node
  zone                 = tostring(count.index + 1)

  tags = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "target_fileserver_data" {
  count              = 2
  managed_disk_id    = azurerm_managed_disk.target_fileserver_data[count.index].id
  virtual_machine_id = azurerm_windows_virtual_machine.target_fileserver[count.index].id
  lun                = 0
  caching            = "ReadWrite"
}

resource "azurerm_network_interface" "target_fileserver" {
  count               = 2
  name                = "${var.resource_prefix}-tgt-fs-${count.index + 1}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.services.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.services.address_prefixes[0], 30 + count.index)
  }

  tags = local.common_tags
}

# =============================================================================
# SMS Orchestrator Cluster
# =============================================================================

resource "azurerm_windows_virtual_machine" "sms_orchestrator" {
  count               = 2 # Redundant orchestrators
  name                = "${var.resource_prefix}-sms-orch-${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_D4s_v5" # 4 vCPU, 16GB RAM
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  zone                = tostring(count.index + 1)

  network_interface_ids = [
    azurerm_network_interface.sms_orchestrator[count.index].id
  ]

  os_disk {
    name                 = "${var.resource_prefix}-sms-orch-${count.index + 1}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 256
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  boot_diagnostics {}

  tags = merge(local.common_tags, {
    Role = "SMS-Orchestrator-Node-${count.index + 1}"
  })
}

resource "azurerm_network_interface" "sms_orchestrator" {
  count               = 2
  name                = "${var.resource_prefix}-sms-orch-${count.index + 1}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.services.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.services.address_prefixes[0], 40 + count.index)
  }

  tags = local.common_tags
}

# =============================================================================
# Load Balancer for File Server Cluster
# =============================================================================

resource "azurerm_lb" "file_cluster" {
  for_each = toset(["source", "target"])

  name                = "${var.resource_prefix}-${each.key}-fs-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "FilesClusterIP"
    subnet_id                     = azurerm_subnet.services.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.services.address_prefixes[0], each.key == "source" ? 25 : 35)
  }

  tags = local.common_tags
}

# Backend pools
resource "azurerm_lb_backend_address_pool" "file_cluster" {
  for_each = toset(["source", "target"])

  name            = "${each.key}-fs-pool"
  loadbalancer_id = azurerm_lb.file_cluster[each.key].id
}

# Health probe
resource "azurerm_lb_probe" "file_cluster" {
  for_each = toset(["source", "target"])

  name                = "smb-health"
  loadbalancer_id     = azurerm_lb.file_cluster[each.key].id
  protocol            = "Tcp"
  port                = 445
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Load balancing rule for SMB
resource "azurerm_lb_rule" "file_cluster_smb" {
  for_each = toset(["source", "target"])

  name                           = "smb-rule"
  loadbalancer_id                = azurerm_lb.file_cluster[each.key].id
  protocol                       = "Tcp"
  frontend_port                  = 445
  backend_port                   = 445
  frontend_ip_configuration_name = "FilesClusterIP"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.file_cluster[each.key].id]
  probe_id                       = azurerm_lb_probe.file_cluster[each.key].id
  idle_timeout_in_minutes        = 30
}

