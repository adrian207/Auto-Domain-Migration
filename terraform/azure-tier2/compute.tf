# Compute Resources - Azure Tier 2 (Production)

# =============================================================================
# SSH KEY (Generated or provided)
# =============================================================================

resource "tls_private_key" "ssh" {
  count     = var.ssh_public_key == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# =============================================================================
# GUACAMOLE BASTION HOST
# =============================================================================

resource "azurerm_public_ip" "guacamole" {
  count               = var.enable_guacamole ? 1 : 0
  name                = "${local.resource_prefix}-guac-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.enable_availability_zones ? ["1"] : []

  tags = local.common_tags
}

resource "azurerm_network_interface" "guacamole" {
  count               = var.enable_guacamole ? 1 : 0
  name                = "${local.resource_prefix}-guac-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Performance optimization: Enable accelerated networking
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.bastion.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.guacamole[0].id
  }
}

resource "azurerm_linux_virtual_machine" "guacamole" {
  count               = var.enable_guacamole ? 1 : 0
  name                = "${local.resource_prefix}-guacamole"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.guacamole_vm_size
  admin_username      = var.admin_username
  zone                = var.enable_availability_zones ? "1" : null

  network_interface_ids = [
    azurerm_network_interface.guacamole[0].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key != "" ? var.ssh_public_key : tls_private_key.ssh[0].public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-lvm-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-guacamole.yaml", {
    postgres_host     = azurerm_postgresql_flexible_server.main.fqdn
    postgres_user     = azurerm_postgresql_flexible_server.main.administrator_login
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

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.main.primary_blob_endpoint
  }

  tags = merge(local.common_tags, { Role = "Bastion" })
}

# Enable backup for Guacamole VM
resource "azurerm_backup_protected_vm" "guacamole" {
  count               = var.enable_guacamole && var.enable_azure_backup ? 1 : 0
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main[0].name
  source_vm_id        = azurerm_linux_virtual_machine.guacamole[0].id
  backup_policy_id    = azurerm_backup_policy_vm.daily[0].id
}

# =============================================================================
# ANSIBLE CONTROLLERS (Multiple for HA)
# =============================================================================

resource "azurerm_network_interface" "ansible" {
  count               = var.num_ansible_controllers
  name                = "${local.resource_prefix}-ansible-${count.index + 1}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Performance optimization: Enable accelerated networking
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.management.address_prefixes[0], 10 + count.index)
  }
}

# Associate Ansible NICs with load balancer backend pool (if HA enabled)
resource "azurerm_network_interface_backend_address_pool_association" "ansible" {
  count                   = var.num_ansible_controllers > 1 ? var.num_ansible_controllers : 0
  network_interface_id    = azurerm_network_interface.ansible[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.ansible[0].id
}

resource "azurerm_linux_virtual_machine" "ansible" {
  count               = var.num_ansible_controllers
  name                = "${local.resource_prefix}-ansible-${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.ansible_vm_size
  admin_username      = var.admin_username
  zone                = var.enable_availability_zones ? local.availability_zones[count.index % length(local.availability_zones)] : null

  network_interface_ids = [
    azurerm_network_interface.ansible[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key != "" ? var.ssh_public_key : tls_private_key.ssh[0].public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS" # Good performance, lower cost
    disk_size_gb         = 40                # Server Core requires less space
  }

  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-lvm-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-ansible.yaml", {
    postgres_host     = azurerm_postgresql_flexible_server.main.fqdn
    postgres_user     = azurerm_postgresql_flexible_server.main.administrator_login
    postgres_password = var.postgres_admin_password
    storage_account   = azurerm_storage_account.main.name
    storage_key       = azurerm_storage_account.main.primary_access_key
    instance_id       = count.index + 1
    num_instances     = var.num_ansible_controllers
    admin_username    = var.admin_username
  }))

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.main.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role     = "Ansible-Controller"
    Instance = count.index + 1
  })
}

# Enable backup for Ansible controllers
resource "azurerm_backup_protected_vm" "ansible" {
  count               = var.enable_azure_backup ? var.num_ansible_controllers : 0
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main[0].name
  source_vm_id        = azurerm_linux_virtual_machine.ansible[count.index].id
  backup_policy_id    = azurerm_backup_policy_vm.daily[0].id
}

# =============================================================================
# MONITORING VM (Prometheus/Grafana)
# =============================================================================

resource "azurerm_network_interface" "monitoring" {
  count               = var.enable_monitoring_stack ? 1 : 0
  name                = "${local.resource_prefix}-monitoring-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Performance optimization: Enable accelerated networking
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.management.address_prefixes[0], 20)
  }
}

resource "azurerm_linux_virtual_machine" "monitoring" {
  count               = var.enable_monitoring_stack ? 1 : 0
  name                = "${local.resource_prefix}-monitoring"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.monitoring_vm_size
  admin_username      = var.admin_username
  zone                = var.enable_availability_zones ? "2" : null

  network_interface_ids = [
    azurerm_network_interface.monitoring[0].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key != "" ? var.ssh_public_key : tls_private_key.ssh[0].public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS" # Good performance, lower cost
    disk_size_gb         = 40                # Server Core requires less space
  }

  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-lvm-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-monitoring.yaml", {
    postgres_host     = azurerm_postgresql_flexible_server.main.fqdn
    postgres_user     = azurerm_postgresql_flexible_server.main.administrator_login
    postgres_password = var.postgres_admin_password
    admin_username    = var.admin_username
  }))

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.main.primary_blob_endpoint
  }

  tags = merge(local.common_tags, { Role = "Monitoring" })
}

# Enable backup for monitoring VM
resource "azurerm_backup_protected_vm" "monitoring" {
  count               = var.enable_monitoring_stack && var.enable_azure_backup ? 1 : 0
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main[0].name
  source_vm_id        = azurerm_linux_virtual_machine.monitoring[0].id
  backup_policy_id    = azurerm_backup_policy_vm.daily[0].id
}

# =============================================================================
# SOURCE DOMAIN CONTROLLER (Windows Server 2022)
# =============================================================================

resource "azurerm_network_interface" "source_dc" {
  name                = "${local.resource_prefix}-source-dc-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.source_domain.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.source_domain.address_prefixes[0], 10)
  }
}

resource "azurerm_windows_virtual_machine" "source_dc" {
  name                = "${local.resource_prefix}-src-dc"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.dc_vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  zone                = var.enable_availability_zones ? "1" : null

  network_interface_ids = [
    azurerm_network_interface.source_dc.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS" # Good performance, lower cost
    disk_size_gb         = 40                # Server Core requires less space
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-core-g2" # Server Core (no GUI) - optimized
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.main.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role   = "Source-DomainController"
    Domain = var.source_domain_fqdn
  })
}

# Enable backup for source DC
resource "azurerm_backup_protected_vm" "source_dc" {
  count               = var.enable_azure_backup ? 1 : 0
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main[0].name
  source_vm_id        = azurerm_windows_virtual_machine.source_dc.id
  backup_policy_id    = azurerm_backup_policy_vm.daily[0].id
}

# =============================================================================
# TARGET DOMAIN CONTROLLER (Windows Server 2022)
# =============================================================================

resource "azurerm_network_interface" "target_dc" {
  name                = "${local.resource_prefix}-target-dc-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.target_domain.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.target_domain.address_prefixes[0], 10)
  }
}

resource "azurerm_windows_virtual_machine" "target_dc" {
  name                = "${local.resource_prefix}-tgt-dc"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.dc_vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  zone                = var.enable_availability_zones ? "2" : null

  network_interface_ids = [
    azurerm_network_interface.target_dc.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS" # Good performance, lower cost
    disk_size_gb         = 40                # Server Core requires less space
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-core-g2" # Server Core (no GUI) - optimized
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.main.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role   = "Target-DomainController"
    Domain = var.target_domain_fqdn
  })
}

# Enable backup for target DC
resource "azurerm_backup_protected_vm" "target_dc" {
  count               = var.enable_azure_backup ? 1 : 0
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main[0].name
  source_vm_id        = azurerm_windows_virtual_machine.target_dc.id
  backup_policy_id    = azurerm_backup_policy_vm.daily[0].id
}

# =============================================================================
# VM EXTENSIONS
# =============================================================================

# Azure CLI extension for Guacamole
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

# Azure Monitor agent for all VMs
resource "azurerm_virtual_machine_extension" "azure_monitor_linux" {
  count                     = var.enable_azure_monitor ? var.num_ansible_controllers : 0
  name                      = "AzureMonitorLinuxAgent"
  virtual_machine_id        = azurerm_linux_virtual_machine.ansible[count.index].id
  publisher                 = "Microsoft.Azure.Monitor"
  type                      = "AzureMonitorLinuxAgent"
  type_handler_version      = "1.28"
  automatic_upgrade_enabled = true

  tags = local.common_tags
}


