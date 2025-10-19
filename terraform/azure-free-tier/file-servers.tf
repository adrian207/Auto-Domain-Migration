# File Servers Configuration for Tier 1 (Free/Demo)
# Purpose: Source and Target file servers for SMS demonstration

# =============================================================================
# Source File Server
# =============================================================================

resource "azurerm_windows_virtual_machine" "source_fileserver" {
  name                = "${local.resource_prefix}-src-fs"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1ms"  # 1 vCPU, 2GB RAM - $15/month
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.source_fileserver.id
  ]

  os_disk {
    name                 = "${local.resource_prefix}-src-fs-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  # Enable boot diagnostics
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.main.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role = "Source-FileServer"
    Tier = "1"
  })
}

# Data disk for source file server
resource "azurerm_managed_disk" "source_fileserver_data" {
  name                 = "${local.resource_prefix}-src-fs-data"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 1024  # 1TB for test data

  tags = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "source_fileserver_data" {
  managed_disk_id    = azurerm_managed_disk.source_fileserver_data.id
  virtual_machine_id = azurerm_windows_virtual_machine.source_fileserver.id
  lun                = 0
  caching            = "ReadWrite"
}

# Network interface for source file server
resource "azurerm_network_interface" "source_fileserver" {
  name                = "${local.resource_prefix}-src-fs-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workstations.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

# =============================================================================
# Target File Server
# =============================================================================

resource "azurerm_windows_virtual_machine" "target_fileserver" {
  name                = "${local.resource_prefix}-tgt-fs"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1ms"  # 1 vCPU, 2GB RAM - $15/month
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.target_fileserver.id
  ]

  os_disk {
    name                 = "${local.resource_prefix}-tgt-fs-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  # Enable boot diagnostics
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.main.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role = "Target-FileServer"
    Tier = "1"
  })
}

# Data disk for target file server
resource "azurerm_managed_disk" "target_fileserver_data" {
  name                 = "${local.resource_prefix}-tgt-fs-data"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 1024  # 1TB

  tags = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "target_fileserver_data" {
  managed_disk_id    = azurerm_managed_disk.target_fileserver_data.id
  virtual_machine_id = azurerm_windows_virtual_machine.target_fileserver.id
  lun                = 0
  caching            = "ReadWrite"
}

# Network interface for target file server
resource "azurerm_network_interface" "target_fileserver" {
  name                = "${local.resource_prefix}-tgt-fs-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workstations.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

# =============================================================================
# VM Extensions for File Servers
# =============================================================================

# Configure source file server
resource "azurerm_virtual_machine_extension" "source_fileserver_config" {
  name                 = "ConfigureFileServer"
  virtual_machine_id   = azurerm_windows_virtual_machine.source_fileserver.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"${file("${path.module}/scripts/Configure-SourceFileServer.ps1")}\""
  })

  tags = local.common_tags
}

# Configure target file server
resource "azurerm_virtual_machine_extension" "target_fileserver_config" {
  name                 = "ConfigureFileServer"
  virtual_machine_id   = azurerm_windows_virtual_machine.target_fileserver.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"${file("${path.module}/scripts/Configure-TargetFileServer.ps1")}\""
  })

  tags = local.common_tags
}

# =============================================================================
# NSG Rules for File Server Access
# =============================================================================

# Allow SMB access
resource "azurerm_network_security_rule" "allow_smb" {
  name                        = "AllowSMB"
  priority                    = 310
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "445"
  source_address_prefix       = azurerm_subnet.workstations.address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

# Allow NetBIOS
resource "azurerm_network_security_rule" "allow_netbios" {
  name                        = "AllowNetBIOS"
  priority                    = 311
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["137", "138", "139"]
  source_address_prefix       = azurerm_subnet.workstations.address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

