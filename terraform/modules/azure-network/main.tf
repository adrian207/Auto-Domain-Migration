# Azure Network Module
# Reusable networking components for Azure deployments

resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  address_space       = var.address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet" "subnets" {
  for_each             = var.subnets
  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value.address_prefix]

  dynamic "delegation" {
    for_each = try(each.value.delegation, null) != null ? [1] : []
    content {
      name = each.value.delegation.name
      service_delegation {
        name    = each.value.delegation.service_name
        actions = each.value.delegation.actions
      }
    }
  }
}

resource "azurerm_network_security_group" "nsgs" {
  for_each            = var.network_security_groups
  name                = each.key
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "rules" {
  for_each = {
    for rule in flatten([
      for nsg_name, nsg in var.network_security_groups : [
        for rule_name, rule in nsg.rules : {
          key                        = "${nsg_name}-${rule_name}"
          nsg_name                   = nsg_name
          name                       = rule_name
          priority                   = rule.priority
          direction                  = rule.direction
          access                     = rule.access
          protocol                   = rule.protocol
          source_port_range          = try(rule.source_port_range, "*")
          destination_port_range     = try(rule.destination_port_range, null)
          destination_port_ranges    = try(rule.destination_port_ranges, null)
          source_address_prefix      = try(rule.source_address_prefix, null)
          source_address_prefixes    = try(rule.source_address_prefixes, null)
          destination_address_prefix = try(rule.destination_address_prefix, "*")
        }
      ]
    ]) : rule.key => rule
  }

  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  destination_port_ranges     = each.value.destination_port_ranges
  source_address_prefix       = each.value.source_address_prefix
  source_address_prefixes     = each.value.source_address_prefixes
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsgs[each.value.nsg_name].name
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  for_each = {
    for subnet_name, subnet in var.subnets : subnet_name => subnet
    if try(subnet.nsg_name, null) != null
  }

  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.nsgs[each.value.nsg_name].id
}


