# Compute Resources - All using B1s (Free tier: 750 hours/month)

# Public IP for Guacamole Bastion
resource "azurerm_public_ip" "guacamole" {
  count               = var.enable_guacamole ? 1 : 0
  name                = "${local.resource_prefix}-guac-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# Network Interface for Guacamole
resource "azurerm_network_interface" "guacamole" {
  count               = var.enable_guacamole ? 1 : 0
  name                = "${local.resource_prefix}-guac-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.bastion.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.guacamole[0].id
  }
}

# Guacamole Bastion VM (B1s - Free tier)
resource "azurerm_linux_virtual_machine" "guacamole" {
  count               = var.enable_guacamole ? 1 : 0
  name                = "${local.resource_prefix}-guacamole"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1s" # FREE: 750 hours/month
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.guacamole[0].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key != "" ? var.ssh_public_key : tls_private_key.ssh[0].public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-lvm-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-guacamole.yaml", {
    postgres_host     = azurerm_postgresql_flexible_server.main.fqdn
    postgres_user     = var.admin_username
    postgres_password = var.guacamole_db_password
    postgres_db       = azurerm_postgresql_flexible_server_database.guacamole.name
    admin_username    = var.admin_username
    admin_password    = var.admin_password
    resource_group    = azurerm_resource_group.main.name
    nsg_name          = azurerm_network_security_group.bastion.name
  }))

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Generate SSH key if not provided
resource "tls_private_key" "ssh" {
  count     = var.ssh_public_key == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Ansible Controller VM (B1s - Free tier)
resource "azurerm_network_interface" "ansible" {
  name                = "${local.resource_prefix}-ansible-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.10"
  }
}

resource "azurerm_linux_virtual_machine" "ansible" {
  name                = "${local.resource_prefix}-ansible"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1s" # FREE: 750 hours/month
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.ansible.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key != "" ? var.ssh_public_key : tls_private_key.ssh[0].public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-lvm-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-ansible.yaml", {
    postgres_host     = azurerm_postgresql_flexible_server.main.fqdn
    postgres_user     = var.admin_username
    postgres_password = var.guacamole_db_password
    storage_account   = azurerm_storage_account.main.name
    storage_key       = azurerm_storage_account.main.primary_access_key
  }))

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Source Domain Controller (B1s - Free tier)
resource "azurerm_network_interface" "source_dc" {
  name                = "${local.resource_prefix}-source-dc-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.source_domain.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.10.10"
  }
}

resource "azurerm_windows_virtual_machine" "source_dc" {
  name                = "${local.resource_prefix}-src-dc"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1s" # FREE: 750 hours/month
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.source_dc.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 127
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition-core"
    version   = "latest"
  }

  tags = merge(
    local.common_tags,
    {
      Role = "Source-DomainController"
    }
  )
}

# Target Domain Controller (B1s - Free tier)
resource "azurerm_network_interface" "target_dc" {
  name                = "${local.resource_prefix}-target-dc-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.target_domain.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.20.10"
  }
}

resource "azurerm_windows_virtual_machine" "target_dc" {
  name                = "${local.resource_prefix}-tgt-dc"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1s" # FREE: 750 hours/month
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.target_dc.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 127
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition-core"
    version   = "latest"
  }

  tags = merge(
    local.common_tags,
    {
      Role = "Target-DomainController"
    }
  )
}

# Test Workstation (for migration testing)
resource "azurerm_network_interface" "test_workstation" {
  name                = "${local.resource_prefix}-ws01-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workstations.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "test_workstation" {
  name                = "${local.resource_prefix}-ws01"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1s" # FREE: 750 hours/month
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.test_workstation.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 127
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-11"
    sku       = "win11-22h2-pro"
    version   = "latest"
  }

  tags = merge(
    local.common_tags,
    {
      Role = "Test-Workstation"
    }
  )
}

# VM Extension for Guacamole - Install Azure CLI and configure managed identity
resource "azurerm_virtual_machine_extension" "guacamole_azcli" {
  count                = var.enable_guacamole ? 1 : 0
  name                 = "install-azure-cli"
  virtual_machine_id   = azurerm_linux_virtual_machine.guacamole[0].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    commandToExecute = "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
  })

  tags = local.common_tags
}

