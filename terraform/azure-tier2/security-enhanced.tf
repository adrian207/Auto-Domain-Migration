# Enhanced Security Features - Azure Tier 2 Optimizations
# Purpose: Implement advanced security controls

# =============================================================================
# AZURE DEFENDER FOR CLOUD (Advanced Threat Protection)
# =============================================================================

resource "azurerm_security_center_subscription_pricing" "vm" {
  count         = var.enable_defender_for_cloud ? 1 : 0
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "storage" {
  count         = var.enable_defender_for_cloud ? 1 : 0
  tier          = "Standard"
  resource_type = "StorageAccounts"
}

resource "azurerm_security_center_subscription_pricing" "database" {
  count         = var.enable_defender_for_cloud ? 1 : 0
  tier          = "Standard"
  resource_type = "OpenSourceRelationalDatabases"
}

resource "azurerm_security_center_subscription_pricing" "keyvault" {
  count         = var.enable_defender_for_cloud && var.enable_key_vault ? 1 : 0
  tier          = "Standard"
  resource_type = "KeyVaults"
}

# =============================================================================
# PRIVATE ENDPOINTS (Network Security)
# =============================================================================

# Private endpoint for Storage Account
resource "azurerm_private_endpoint" "storage" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "${local.resource_prefix}-storage-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.management.id

  private_service_connection {
    name                           = "storage-privateserviceconnection"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "storage-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage[0].id]
  }

  tags = local.common_tags
}

# Private DNS Zone for Storage
resource "azurerm_private_dns_zone" "storage" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  count                 = var.enable_private_endpoints ? 1 : 0
  name                  = "${local.resource_prefix}-storage-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.storage[0].name
  virtual_network_id    = azurerm_virtual_network.main.id

  tags = local.common_tags
}

# Private endpoint for Key Vault
resource "azurerm_private_endpoint" "keyvault" {
  count               = var.enable_private_endpoints && var.enable_key_vault ? 1 : 0
  name                = "${local.resource_prefix}-kv-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.management.id

  private_service_connection {
    name                           = "keyvault-privateserviceconnection"
    private_connection_resource_id = azurerm_key_vault.main[0].id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "keyvault-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault[0].id]
  }

  tags = local.common_tags
}

# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "keyvault" {
  count               = var.enable_private_endpoints && var.enable_key_vault ? 1 : 0
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  count                 = var.enable_private_endpoints && var.enable_key_vault ? 1 : 0
  name                  = "${local.resource_prefix}-kv-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault[0].name
  virtual_network_id    = azurerm_virtual_network.main.id

  tags = local.common_tags
}

# =============================================================================
# CUSTOMER-MANAGED KEYS (CMK) FOR ENCRYPTION
# =============================================================================

# Key for storage account encryption
resource "azurerm_key_vault_key" "storage" {
  count        = var.enable_cmk_encryption && var.enable_key_vault ? 1 : 0
  name         = "storage-cmk"
  key_vault_id = azurerm_key_vault.main[0].id
  key_type     = "RSA"
  key_size     = 4096

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [
    azurerm_key_vault_access_policy.ansible
  ]

  tags = local.common_tags
}

# Key for disk encryption
resource "azurerm_key_vault_key" "disk" {
  count        = var.enable_cmk_encryption && var.enable_key_vault ? 1 : 0
  name         = "disk-cmk"
  key_vault_id = azurerm_key_vault.main[0].id
  key_type     = "RSA"
  key_size     = 4096

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [
    azurerm_key_vault_access_policy.ansible
  ]

  tags = local.common_tags
}

# Disk Encryption Set for VMs
resource "azurerm_disk_encryption_set" "main" {
  count               = var.enable_cmk_encryption && var.enable_key_vault ? 1 : 0
  name                = "${local.resource_prefix}-des"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  key_vault_key_id    = azurerm_key_vault_key.disk[0].id

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Grant DES access to Key Vault
resource "azurerm_key_vault_access_policy" "disk_encryption" {
  count        = var.enable_cmk_encryption && var.enable_key_vault ? 1 : 0
  key_vault_id = azurerm_key_vault.main[0].id
  tenant_id    = azurerm_disk_encryption_set.main[0].identity[0].tenant_id
  object_id    = azurerm_disk_encryption_set.main[0].identity[0].principal_id

  key_permissions = [
    "Get",
    "WrapKey",
    "UnwrapKey"
  ]
}

# =============================================================================
# JUST-IN-TIME (JIT) VM ACCESS
# =============================================================================

resource "azurerm_security_center_jit_access_policy" "main" {
  count             = var.enable_jit_access ? 1 : 0
  resource_group_id = azurerm_resource_group.main.id
  name              = "${local.resource_prefix}-jit-policy"
  location          = azurerm_resource_group.main.location

  # SSH access to Ansible controllers
  dynamic "jit_policy_rule" {
    for_each = range(var.num_ansible_controllers)
    content {
      vm_id = azurerm_linux_virtual_machine.ansible[jit_policy_rule.value].id

      port {
        number                        = 22
        protocol                      = "Tcp"
        allowed_source_address_prefix = var.allowed_ip_ranges[0]
        max_request_access_duration   = "PT3H"
      }
    }
  }

  # RDP access to Domain Controllers
  jit_policy_rule {
    vm_id = azurerm_windows_virtual_machine.source_dc.id

    port {
      number                        = 3389
      protocol                      = "Tcp"
      allowed_source_address_prefix = var.allowed_ip_ranges[0]
      max_request_access_duration   = "PT3H"
    }
  }

  jit_policy_rule {
    vm_id = azurerm_windows_virtual_machine.target_dc.id

    port {
      number                        = 3389
      protocol                      = "Tcp"
      allowed_source_address_prefix = var.allowed_ip_ranges[0]
      max_request_access_duration   = "PT3H"
    }
  }
}

# =============================================================================
# NETWORK SECURITY - AZURE FIREWALL (Optional)
# =============================================================================

# Azure Firewall Subnet
resource "azurerm_subnet" "firewall" {
  count                = var.enable_azure_firewall ? 1 : 0
  name                 = "AzureFirewallSubnet" # Must be this exact name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.255.0/24"]
}

# Public IP for Azure Firewall
resource "azurerm_public_ip" "firewall" {
  count               = var.enable_azure_firewall ? 1 : 0
  name                = "${local.resource_prefix}-fw-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

# Azure Firewall
resource "azurerm_firewall" "main" {
  count               = var.enable_azure_firewall ? 1 : 0
  name                = "${local.resource_prefix}-fw"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.azure_firewall_tier

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall[0].id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }

  tags = local.common_tags
}

# Firewall Policy
resource "azurerm_firewall_policy" "main" {
  count               = var.enable_azure_firewall ? 1 : 0
  name                = "${local.resource_prefix}-fw-policy"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  threat_intelligence_mode = "Alert"

  tags = local.common_tags
}

