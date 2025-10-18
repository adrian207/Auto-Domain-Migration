# Virtual Network and Subnets
resource "azurerm_virtual_network" "main" {
  name                = "${local.resource_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Bastion Subnet (for Guacamole)
resource "azurerm_subnet" "bastion" {
  name                 = "bastion-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Management Subnet (Ansible controller, monitoring)
resource "azurerm_subnet" "management" {
  name                 = "management-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
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

# Workstation Subnet (test VMs to migrate)
resource "azurerm_subnet" "workstations" {
  name                 = "workstations-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.30.0/24"]
}

# Network Security Group for Bastion (Guacamole)
resource "azurerm_network_security_group" "bastion" {
  name                = "${local.resource_prefix}-bastion-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Bastion NSG Rules
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

resource "azurerm_network_security_rule" "bastion_ssh" {
  name                        = "Allow-SSH-Inbound"
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

resource "azurerm_network_security_rule" "bastion_outbound" {
  name                        = "Allow-All-Outbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

# Associate NSG with Bastion Subnet
resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}

# Network Security Group for Management
resource "azurerm_network_security_group" "management" {
  name                = "${local.resource_prefix}-mgmt-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Management NSG Rules - SSH and WinRM from bastion only
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

# Associate NSG with Management Subnet
resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

# Network Security Group for Domain Controllers
resource "azurerm_network_security_group" "domain" {
  name                = "${local.resource_prefix}-domain-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Domain NSG Rules - AD ports
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

# Associate NSG with Source Domain Subnet
resource "azurerm_subnet_network_security_group_association" "source_domain" {
  subnet_id                 = azurerm_subnet.source_domain.id
  network_security_group_id = azurerm_network_security_group.domain.id
}

# Associate NSG with Target Domain Subnet
resource "azurerm_subnet_network_security_group_association" "target_domain" {
  subnet_id                 = azurerm_subnet.target_domain.id
  network_security_group_id = azurerm_network_security_group.domain.id
}

