# Network Configuration for Tier 3
# Purpose: VNet, subnets, NSGs, and network security

# =============================================================================
# Virtual Network
# =============================================================================

resource "azurerm_virtual_network" "main" {
  name                = "${local.resource_prefix}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space

  tags = local.common_tags
}

# =============================================================================
# Subnets
# =============================================================================

# AKS subnet
resource "azurerm_subnet" "aks" {
  name                 = "${local.resource_prefix}-aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_address_prefix]
}

# Application Gateway subnet
resource "azurerm_subnet" "appgw" {
  name                 = "${local.resource_prefix}-appgw-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.appgw_subnet_address_prefix]
}

# Services subnet (for domain controllers and other services)
resource "azurerm_subnet" "services" {
  name                 = "${local.resource_prefix}-services-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.services_subnet_address_prefix]
}

# =============================================================================
# Network Security Groups
# =============================================================================

# NSG for AKS subnet
resource "azurerm_network_security_group" "aks" {
  name                = "${local.resource_prefix}-aks-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Allow internal AKS traffic
resource "azurerm_network_security_rule" "aks_internal" {
  name                        = "AllowAKSInternal"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.aks_subnet_address_prefix
  destination_address_prefix  = var.aks_subnet_address_prefix
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.aks.name
}

# Allow load balancer health probes
resource "azurerm_network_security_rule" "aks_lb" {
  name                        = "AllowAzureLoadBalancer"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.aks.name
}

# Associate NSG with AKS subnet
resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

# NSG for services subnet
resource "azurerm_network_security_group" "services" {
  name                = "${local.resource_prefix}-services-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Allow RDP from AKS to services
resource "azurerm_network_security_rule" "services_rdp_from_aks" {
  name                        = "AllowRDPFromAKS"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = var.aks_subnet_address_prefix
  destination_address_prefix  = var.services_subnet_address_prefix
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.services.name
}

# Allow WinRM from AKS to services
resource "azurerm_network_security_rule" "services_winrm_from_aks" {
  name                        = "AllowWinRMFromAKS"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["5985", "5986"]
  source_address_prefix       = var.aks_subnet_address_prefix
  destination_address_prefix  = var.services_subnet_address_prefix
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.services.name
}

# Allow AD traffic
resource "azurerm_network_security_rule" "services_ad" {
  name                        = "AllowADFromAKS"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["53", "88", "135", "139", "389", "445", "464", "636", "3268", "3269"]
  source_address_prefix       = var.aks_subnet_address_prefix
  destination_address_prefix  = var.services_subnet_address_prefix
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.services.name
}

# Associate NSG with services subnet
resource "azurerm_subnet_network_security_group_association" "services" {
  subnet_id                 = azurerm_subnet.services.id
  network_security_group_id = azurerm_network_security_group.services.id
}

# =============================================================================
# Public IP for Load Balancer
# =============================================================================

resource "azurerm_public_ip" "lb" {
  name                = "${local.resource_prefix}-lb-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  tags = local.common_tags
}

# =============================================================================
# DDoS Protection Plan (Optional - expensive)
# =============================================================================

# resource "azurerm_network_ddos_protection_plan" "main" {
#   name                = "${local.resource_prefix}-ddos"
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
#
#   tags = local.common_tags
# }

# =============================================================================
# Private DNS Zone for AKS
# =============================================================================

resource "azurerm_private_dns_zone" "aks" {
  count               = var.enable_private_cluster ? 1 : 0
  name                = "privatelink.${var.location}.azmk8s.io"
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  count                 = var.enable_private_cluster ? 1 : 0
  name                  = "${local.resource_prefix}-aks-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.aks[0].name
  virtual_network_id    = azurerm_virtual_network.main.id

  tags = local.common_tags
}

# =============================================================================
# NAT Gateway (for secure outbound connectivity)
# =============================================================================

resource "azurerm_public_ip" "nat" {
  name                = "${local.resource_prefix}-nat-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]

  tags = local.common_tags
}

resource "azurerm_nat_gateway" "main" {
  name                    = "${local.resource_prefix}-nat"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10

  tags = local.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "aks" {
  subnet_id      = azurerm_subnet.aks.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

