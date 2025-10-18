# Network Configuration - Azure Tier 2 (Production)

# =============================================================================
# VIRTUAL NETWORK
# =============================================================================

resource "azurerm_virtual_network" "main" {
  name                = "${local.resource_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# =============================================================================
# SUBNETS
# =============================================================================

# Bastion Subnet (for Guacamole)
resource "azurerm_subnet" "bastion" {
  name                 = "bastion-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Management Subnet (Ansible controllers, monitoring)
resource "azurerm_subnet" "management" {
  name                 = "management-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Database Subnet (PostgreSQL cluster)
resource "azurerm_subnet" "database" {
  name                 = "database-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]

  delegation {
    name = "postgres-delegation"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Source Domain Subnet
resource "azurerm_subnet" "source_domain" {
  name                 = "source-domain-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.10.0/24"]
}

# Target Domain Subnet
resource "azurerm_subnet" "target_domain" {
  name                 = "target-domain-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.20.0/24"]
}

# Workstation Subnet (test/production migration targets)
resource "azurerm_subnet" "workstations" {
  name                 = "workstations-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.30.0/24"]
}

# =============================================================================
# NETWORK SECURITY GROUPS
# =============================================================================

# Bastion NSG
resource "azurerm_network_security_group" "bastion" {
  name                = "${local.resource_prefix}-bastion-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_network_security_rule" "bastion_https" {
  name                        = "Allow-HTTPS-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.allowed_ip_ranges
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_network_security_rule" "bastion_ssh_mgmt" {
  name                        = "Allow-SSH-From-Management"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.allowed_ip_ranges
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_network_security_rule" "bastion_deny_all" {
  name                        = "Deny-All-Inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}

# Management NSG
resource "azurerm_network_security_group" "management" {
  name                = "${local.resource_prefix}-mgmt-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_network_security_rule" "mgmt_ssh_from_bastion" {
  name                        = "Allow-SSH-From-Bastion"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = azurerm_subnet.bastion.address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.management.name
}

resource "azurerm_network_security_rule" "mgmt_winrm_from_bastion" {
  name                        = "Allow-WinRM-From-Bastion"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["5985", "5986"]
  source_address_prefix       = azurerm_subnet.bastion.address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.management.name
}

# Allow Ansible controllers to communicate with each other
resource "azurerm_network_security_rule" "mgmt_internal" {
  name                        = "Allow-Internal-Management"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = azurerm_subnet.management.address_prefixes[0]
  destination_address_prefix  = azurerm_subnet.management.address_prefixes[0]
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.management.name
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

# Database NSG
resource "azurerm_network_security_group" "database" {
  name                = "${local.resource_prefix}-db-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_network_security_rule" "db_postgres_from_vnet" {
  name                        = "Allow-PostgreSQL-From-VNet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.database.name
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id
}

# Domain NSG
resource "azurerm_network_security_group" "domain" {
  name                = "${local.resource_prefix}-domain-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_network_security_rule" "domain_ad_tcp" {
  name                        = "Allow-AD-TCP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["53", "88", "135", "139", "389", "445", "464", "636", "3268", "3269", "49152-65535"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.domain.name
}

resource "azurerm_network_security_rule" "domain_ad_udp" {
  name                        = "Allow-AD-UDP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_ranges     = ["53", "88", "123", "137", "138", "389", "464"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.domain.name
}

resource "azurerm_network_security_rule" "domain_rdp_from_bastion" {
  name                        = "Allow-RDP-From-Bastion"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = azurerm_subnet.bastion.address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.domain.name
}

resource "azurerm_subnet_network_security_group_association" "source_domain" {
  subnet_id                 = azurerm_subnet.source_domain.id
  network_security_group_id = azurerm_network_security_group.domain.id
}

resource "azurerm_subnet_network_security_group_association" "target_domain" {
  subnet_id                 = azurerm_subnet.target_domain.id
  network_security_group_id = azurerm_network_security_group.domain.id
}

# =============================================================================
# NSG FLOW LOGS (if enabled)
# =============================================================================

resource "azurerm_network_watcher_flow_log" "bastion" {
  count                = var.enable_nsg_flow_logs && var.enable_log_analytics ? 1 : 0
  name                 = "${local.resource_prefix}-bastion-flow-log"
  network_watcher_name = "NetworkWatcher_${var.location}"
  resource_group_name  = "NetworkWatcherRG"

  target_resource_id = azurerm_network_security_group.bastion.id
  storage_account_id = azurerm_storage_account.main.id
  enabled            = true

  retention_policy {
    enabled = true
    days    = 90
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.main[0].workspace_id
    workspace_region      = azurerm_log_analytics_workspace.main[0].location
    workspace_resource_id = azurerm_log_analytics_workspace.main[0].id
  }
}

# =============================================================================
# LOAD BALANCER (for Ansible controllers)
# =============================================================================

resource "azurerm_public_ip" "ansible_lb" {
  count               = var.num_ansible_controllers > 1 ? 1 : 0
  name                = "${local.resource_prefix}-ansible-lb-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = local.availability_zones

  tags = local.common_tags
}

resource "azurerm_lb" "ansible" {
  count               = var.num_ansible_controllers > 1 ? 1 : 0
  name                = "${local.resource_prefix}-ansible-lb"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "ansible-frontend"
    public_ip_address_id = azurerm_public_ip.ansible_lb[0].id
  }

  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "ansible" {
  count           = var.num_ansible_controllers > 1 ? 1 : 0
  loadbalancer_id = azurerm_lb.ansible[0].id
  name            = "ansible-backend-pool"
}

resource "azurerm_lb_probe" "ansible_ssh" {
  count           = var.num_ansible_controllers > 1 ? 1 : 0
  loadbalancer_id = azurerm_lb.ansible[0].id
  name            = "ssh-probe"
  protocol        = "Tcp"
  port            = 22
}

resource "azurerm_lb_rule" "ansible_ssh" {
  count                          = var.num_ansible_controllers > 1 ? 1 : 0
  loadbalancer_id                = azurerm_lb.ansible[0].id
  name                           = "ssh-rule"
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  frontend_ip_configuration_name = "ansible-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.ansible[0].id]
  probe_id                       = azurerm_lb_probe.ansible_ssh[0].id
}


