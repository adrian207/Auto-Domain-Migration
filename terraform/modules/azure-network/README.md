# Azure Network Module

Reusable Terraform module for creating Azure networking resources.

## Features

- Virtual Network creation
- Multiple subnets with optional delegations
- Network Security Groups (NSGs)
- NSG rules
- Subnet-NSG associations

## Usage

```hcl
module "network" {
  source = "./modules/azure-network"

  vnet_name           = "my-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "eastus"
  resource_group_name = "my-rg"

  subnets = {
    "web-subnet" = {
      address_prefix = "10.0.1.0/24"
      nsg_name       = "web-nsg"
    }
    "app-subnet" = {
      address_prefix = "10.0.2.0/24"
      nsg_name       = "app-nsg"
    }
  }

  network_security_groups = {
    "web-nsg" = {
      rules = {
        "allow-https" = {
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          destination_port_range     = "443"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        }
      }
    }
    "app-nsg" = {
      rules = {
        "allow-app" = {
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          destination_port_range     = "8080"
          source_address_prefix      = "10.0.1.0/24"
          destination_address_prefix = "*"
        }
      }
    }
  }

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
```

## Outputs

- `vnet_id` - Virtual network ID
- `vnet_name` - Virtual network name
- `subnet_ids` - Map of subnet names to IDs
- `nsg_ids` - Map of NSG names to IDs


