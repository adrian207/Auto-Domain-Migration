# Azure Compute Module

Reusable Terraform module for creating Azure virtual machines (Linux or Windows).

## Features

- Linux or Windows VM creation
- Optional public IP
- Availability zone support
- Managed identity
- Data disk attachment
- Boot diagnostics
- Custom data (cloud-init) support

## Usage

### Linux VM Example

```hcl
module "linux_vm" {
  source = "./modules/azure-compute"

  vm_name             = "my-linux-vm"
  location            = "eastus"
  resource_group_name = "my-rg"
  vm_size             = "Standard_D2s_v5"
  os_type             = "linux"
  admin_username      = "azureadmin"
  ssh_public_key      = file("~/.ssh/id_rsa.pub")
  subnet_id           = module.network.subnet_ids["app-subnet"]
  availability_zone   = "1"
  
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"
  
  enable_managed_identity = true
  
  data_disks = {
    "data01" = {
      size_gb = 100
      type    = "Premium_LRS"
      lun     = 0
    }
  }
  
  tags = {
    Environment = "Production"
  }
}
```

### Windows VM Example

```hcl
module "windows_vm" {
  source = "./modules/azure-compute"

  vm_name             = "my-windows-vm"
  location            = "eastus"
  resource_group_name = "my-rg"
  vm_size             = "Standard_D4s_v5"
  os_type             = "windows"
  admin_username      = "azureadmin"
  admin_password      = "SecurePassword123!"
  subnet_id           = module.network.subnet_ids["app-subnet"]
  
  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2022-datacenter-azure-edition"
  
  create_public_ip = true
  
  tags = {
    Environment = "Production"
  }
}
```

## Outputs

- `vm_id` - Virtual machine ID
- `vm_name` - Virtual machine name
- `private_ip_address` - Private IP address
- `public_ip_address` - Public IP address (if created)
- `network_interface_id` - Network interface ID
- `identity_principal_id` - Managed identity principal ID (if enabled)


