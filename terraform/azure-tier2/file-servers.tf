# File Servers Configuration for Tier 2 (Production)
# Purpose: Source and Target file servers with SMS

# Note: For Tier 2, we recommend Azure Files Premium for better scalability
# This configuration includes both VM-based and Azure Files options

# =============================================================================
# Option A: VM-Based File Servers (Traditional)
# =============================================================================

resource "azurerm_windows_virtual_machine" "source_fileserver" {
  count               = var.use_vm_file_servers ? 1 : 0
  name                = "${local.resource_prefix}-src-fs"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_D4s_v5"  # 4 vCPU, 16GB RAM
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.source_fileserver[0].id
  ]

  os_disk {
    name                 = "${local.resource_prefix}-src-fs-osdisk"
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

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.main.primary_blob_endpoint
  }

  tags = var.tags
}

resource "azurerm_managed_disk" "source_fileserver_data" {
  count                = var.use_vm_file_servers ? 1 : 0
  name                 = "${local.resource_prefix}-src-fs-data"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 2048  # 2TB

  tags = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "source_fileserver_data" {
  count              = var.use_vm_file_servers ? 1 : 0
  managed_disk_id    = azurerm_managed_disk.source_fileserver_data[0].id
  virtual_machine_id = azurerm_windows_virtual_machine.source_fileserver[0].id
  lun                = 0
  caching            = "ReadWrite"
}

resource "azurerm_network_interface" "source_fileserver" {
  count               = var.use_vm_file_servers ? 1 : 0
  name                = "${local.resource_prefix}-src-fs-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workstations.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.workstations.address_prefixes[0], 10)
  }

  tags = var.tags
}

# Target File Server
resource "azurerm_windows_virtual_machine" "target_fileserver" {
  count               = var.use_vm_file_servers ? 1 : 0
  name                = "${local.resource_prefix}-tgt-fs"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_D4s_v5"  # 4 vCPU, 16GB RAM
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.target_fileserver[0].id
  ]

  os_disk {
    name                 = "${local.resource_prefix}-tgt-fs-osdisk"
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

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.main.primary_blob_endpoint
  }

  tags = var.tags
}

resource "azurerm_managed_disk" "target_fileserver_data" {
  count                = var.use_vm_file_servers ? 1 : 0
  name                 = "${local.resource_prefix}-tgt-fs-data"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 2048  # 2TB

  tags = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "target_fileserver_data" {
  count              = var.use_vm_file_servers ? 1 : 0
  managed_disk_id    = azurerm_managed_disk.target_fileserver_data[0].id
  virtual_machine_id = azurerm_windows_virtual_machine.target_fileserver[0].id
  lun                = 0
  caching            = "ReadWrite"
}

resource "azurerm_network_interface" "target_fileserver" {
  count               = var.use_vm_file_servers ? 1 : 0
  name                = "${local.resource_prefix}-tgt-fs-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workstations.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.workstations.address_prefixes[0], 11)
  }

  tags = var.tags
}

# =============================================================================
# Option B: Azure Files Premium (Recommended for Tier 2)
# =============================================================================

resource "azurerm_storage_account" "file_storage" {
  count                    = var.use_vm_file_servers ? 0 : 1
  name                     = "${replace(local.resource_prefix, "-", "")}files"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Premium"
  account_replication_type = "LRS"
  account_kind             = "FileStorage"

  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.workstations.id]
  }

  tags = var.tags
}

resource "azurerm_storage_share" "source_shares" {
  count                = var.use_vm_file_servers ? 0 : 3
  name                 = ["hr", "finance", "engineering"][count.index]
  storage_account_id   = azurerm_storage_account.file_storage[0].id
  quota                = 500  # 500 GB per share

  enabled_protocol = "SMB"
}

resource "azurerm_storage_share" "target_shares" {
  count                = var.use_vm_file_servers ? 0 : 3
  name                 = "${["hr", "finance", "engineering"][count.index]}-target"
  storage_account_id   = azurerm_storage_account.file_storage[0].id
  quota                = 500  # 500 GB per share

  enabled_protocol = "SMB"
}

# Private endpoint for Azure Files
resource "azurerm_private_endpoint" "file_storage" {
  count               = var.use_vm_file_servers ? 0 : 1
  name                = "${local.resource_prefix}-files-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.workstations.id

  private_service_connection {
    name                           = "${local.resource_prefix}-files-psc"
    private_connection_resource_id = azurerm_storage_account.file_storage[0].id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  tags = var.tags
}

# =============================================================================
# SMS Orchestrator (required for both options)
# =============================================================================

resource "azurerm_windows_virtual_machine" "sms_orchestrator" {
  name                = "${local.resource_prefix}-sms-orch"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_D2s_v5"  # 2 vCPU, 8GB RAM
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.sms_orchestrator.id
  ]

  os_disk {
    name                 = "${local.resource_prefix}-sms-orch-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.main.primary_blob_endpoint
  }

  tags = merge(var.tags, {
    Role = "SMS-Orchestrator"
  })
}

resource "azurerm_network_interface" "sms_orchestrator" {
  name                = "${local.resource_prefix}-sms-orch-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workstations.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.workstations.address_prefixes[0], 12)
  }

  tags = var.tags
}

