# Azure Free Tier Implementation Guide – Tier 1 (Demo)

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

**Purpose:** Deploy a fully functional identity and domain migration demo environment on Azure's free tier with **zero or near-zero cost**, fully automated via Terraform and Ansible.

**Target Audience:** Organizations wanting to pilot/demo the solution before committing budget.

**Cost Target:** $0-5/month (within Azure free tier limits)

---

## 1) Azure Free Tier Overview

### 1.1 What's Included (12 Months Free)

| Service | Free Tier Allowance | Our Usage (Demo) | Cost |
|---------|---------------------|------------------|------|
| **Virtual Machines** | 750 hours/month B1s (Linux) + 750 hours/month B1s (Windows) | 2x B1s Linux (AWX, Postgres) + 1x B1s Windows (test target) | **$0** |
| **Storage** | 5 GB LRS blob storage + 64 GB managed disks | 5 GB blob (USMT states) + 3x 32 GB OS disks | **$0** |
| **Bandwidth** | 100 GB outbound | <10 GB (on-prem to Azure VPN traffic) | **$0** |
| **SQL Database** | 250 GB storage | N/A (using PostgreSQL instead) | **$0** |
| **PostgreSQL** | Burstable B1ms (1 vCore, 2 GB RAM) for 12 months | 1x Burstable B1ms | **$0** |
| **VPN Gateway** | **NOT FREE** | 1x Basic VPN Gateway | **~$27/month** ⚠️ |
| **Key Vault** | 10,000 operations/month | <1,000 ops | **$0** |
| **Azure Monitor** | 5 GB log ingestion | <1 GB (demo scope) | **$0** |

**Total Cost:** **$0-30/month** (VPN Gateway is only paid component if you need site-to-site connectivity)

### 1.2 Always Free Services

| Service | Allowance | Our Usage |
|---------|-----------|-----------|
| **Azure AD (Entra ID)** | 50,000 objects | <500 (demo users) |
| **Azure Functions** | 1M executions/month | Optional (self-healing automation) |
| **Azure Automation** | 500 minutes/month | Optional (runbooks) |
| **Azure DevOps** | 5 users, 1,800 build minutes/month | Optional (CI/CD) |

**Strategy:** Avoid VPN Gateway cost by deploying **Apache Guacamole** (open-source bastion host) with dynamic IP address handling instead of Azure Bastion ($140+/month).

---

## 2) Architecture – Azure Free Tier Demo

### 2.1 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Subscription                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Resource Group: rg-migration-demo                        │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────┐     │  │
│  │  │ Virtual Network: vnet-migration-demo            │     │  │
│  │  │ Address Space: 10.200.0.0/16                    │     │  │
│  │  │                                                  │     │  │
│  │  │  ┌───────────────────────────────────────────┐  │     │  │
│  │  │  │ Subnet: snet-bastion                      │  │     │  │
│  │  │  │ 10.200.0.0/28 (DMZ)                       │  │     │  │
│  │  │  │                                           │  │     │  │
│  │  │  │  ┌──────────────────────────────────┐    │  │     │  │
│  │  │  │  │ VM: vm-guacamole-bastion         │    │  │     │  │
│  │  │  │  │ Size: B1s (1 vCPU, 1 GB RAM)     │    │  │     │  │
│  │  │  │  │ OS: Ubuntu 22.04 LTS             │    │  │     │  │
│  │  │  │  │ Role: Guacamole web gateway      │    │  │     │  │
│  │  │  │  │ IP: 10.200.0.4 (private)         │    │  │     │  │
│  │  │  │  │     <public IP - HTTPS only>     │    │  │     │  │
│  │  │  │  │ Ports: 443 (web UI)              │    │  │     │  │
│  │  │  │  └──────────────────────────────────┘    │  │     │  │
│  │  │  └───────────────────────────────────────────┘  │     │  │
│  │  │                                                  │     │  │
│  │  │  ┌───────────────────────────────────────────┐  │     │  │
│  │  │  │ Subnet: snet-control-plane                │  │     │  │
│  │  │  │ 10.200.1.0/24 (PRIVATE - no public IPs)   │  │     │  │
│  │  │  │                                           │  │     │  │
│  │  │  │  ┌──────────────────────────────────┐    │  │     │  │
│  │  │  │  │ VM: vm-awx-demo                  │    │  │     │  │
│  │  │  │  │ Size: B1s (1 vCPU, 1 GB RAM)     │    │  │     │  │
│  │  │  │  │ OS: Ubuntu 22.04 LTS             │    │  │     │  │
│  │  │  │  │ Role: AWX (Ansible Tower)        │    │  │     │  │
│  │  │  │  │ Disk: 32 GB Standard SSD (free)  │    │  │     │  │
│  │  │  │  │ IP: 10.200.1.10 (private only)   │    │  │     │  │
│  │  │  │  │ Access: Via Guacamole            │    │  │     │  │
│  │  │  │  └──────────────────────────────────┘    │  │     │  │
│  │  │  │                                           │  │     │  │
│  │  │  │  ┌──────────────────────────────────┐    │  │     │  │
│  │  │  │  │ Azure Database for PostgreSQL    │    │  │     │  │
│  │  │  │  │ Tier: Burstable B1ms (FREE)      │    │  │     │  │
│  │  │  │  │ Storage: 32 GB                   │    │  │     │  │
│  │  │  │  │ Role: Reporting + Guacamole DB   │    │  │     │  │
│  │  │  │  │ Private endpoint: 10.200.1.20    │    │  │     │  │
│  │  │  │  └──────────────────────────────────┘    │  │     │  │
│  │  │  └───────────────────────────────────────────┘  │     │  │
│  │  │                                                  │     │  │
│  │  │  ┌───────────────────────────────────────────┐  │     │  │
│  │  │  │ Subnet: snet-target-workstations          │  │     │  │
│  │  │  │ 10.200.2.0/24 (PRIVATE - no public IPs)   │  │     │  │
│  │  │  │                                           │  │     │  │
│  │  │  │  ┌──────────────────────────────────┐    │  │     │  │
│  │  │  │  │ VM: vm-test-workstation-01       │    │  │     │  │
│  │  │  │  │ Size: B1s (1 vCPU, 1 GB RAM)     │    │  │     │  │
│  │  │  │  │ OS: Windows 11 Pro (free tier)   │    │  │     │  │
│  │  │  │  │ Role: Test migration target      │    │  │     │  │
│  │  │  │  │ Disk: 64 GB Standard SSD (free)  │    │  │     │  │
│  │  │  │  │ IP: 10.200.2.10 (private only)   │    │  │     │  │
│  │  │  │  │ Access: Via Guacamole (RDP)      │    │  │     │  │
│  │  │  │  └──────────────────────────────────┘    │  │     │  │
│  │  │  └───────────────────────────────────────────┘  │     │  │
│  │  └─────────────────────────────────────────────────┘     │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────┐     │  │
│  │  │ Storage Account: stmigdemo<random>              │     │  │
│  │  │ SKU: Standard_LRS                               │     │  │
│  │  │ Blob Container: usmt-states (5 GB free)         │     │  │
│  │  │ Lifecycle: Delete after 30 days                 │     │  │
│  │  └─────────────────────────────────────────────────┘     │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────┐     │  │
│  │  │ Key Vault: kv-migration-demo                    │     │  │
│  │  │ SKU: Standard                                   │     │  │
│  │  │ Secrets: domain-admin, service-accounts         │     │  │
│  │  └─────────────────────────────────────────────────┘     │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────┐     │  │
│  │  │ Network Security Group: nsg-control-plane       │     │  │
│  │  │ Rules: Allow 443 (AWX), 22 (SSH), 5432 (Postgres) │  │  │
│  │  └─────────────────────────────────────────────────┘     │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
        │
        │ (No VPN Gateway to save $27/month)
        │ Access via Azure Bastion or Public IPs
        ▼
┌─────────────────────────────────────────┐
│     On-Premises (Source Domain)         │
│  - Source AD: olddomain.local           │
│  - Source workstations (to migrate)     │
│  - VPN to Azure (optional, for prod)    │
└─────────────────────────────────────────┘
```

### 2.2 Apache Guacamole Bastion Benefits

**Why Guacamole Instead of Azure Bastion?**

| Feature | Azure Bastion | Guacamole (Open-Source) |
|---------|---------------|-------------------------|
| **Cost** | $140+/month | **$0** (within free tier B1s VM) |
| **Access** | Azure Portal only | Web browser (any device) |
| **Protocols** | RDP, SSH | RDP, SSH, VNC, Telnet |
| **Recording** | Limited | Full session recording |
| **MFA** | Azure AD only | TOTP, Duo, LDAP |
| **Customization** | None | Fully customizable |
| **Dynamic IP** | Not needed | Script-based NSG updates |

**What You Get:**
- ✅ Single HTTPS URL for all server access (no VPN needed)
- ✅ Web-based SSH, RDP, VNC in browser (no client software)
- ✅ Automatic dynamic IP address updates
- ✅ Session recording and auditing
- ✅ Copy/paste between local and remote machines
- ✅ File transfer via SFTP browser
- ✅ Multi-user with RBAC
- ✅ Zero cost (within free tier)

**Access Flow:**
```
Your Home/Office (Dynamic IP)
    │
    ▼ HTTPS (443) - NSG auto-updated by script
Guacamole Bastion (10.200.0.4)
    │
    ├──▶ SSH → AWX (10.200.1.10)
    ├──▶ SSH → PostgreSQL (10.200.1.20)
    └──▶ RDP → Test Workstation (10.200.2.10)
```

---

### 2.3 Cost Optimization Strategies

**To Stay in Free Tier:**

1. ✅ **Use B1s VMs** (750 hours/month free for 12 months)
   - 1x B1s Linux for Guacamole → **$0**
   - 1x B1s Linux for AWX → **$0**
   - 1x B1s Windows for test target → **$0**

2. ✅ **Use Burstable PostgreSQL** (B1ms free for 12 months)
   - 1 vCore, 2 GB RAM, 32 GB storage → **$0**

3. ✅ **Use Standard_LRS blob storage** (5 GB free)
   - USMT state stores → **$0** (if <5 GB)

4. ✅ **Avoid VPN Gateway** ($27/month)
   - Use public IPs with NSG restrictions
   - Or use Azure Bastion (free tier available)

5. ✅ **Auto-shutdown VMs** when not in use
   - Schedule: Stop at 6 PM, start at 8 AM weekdays
   - Saves hours for actual demo/testing

6. ✅ **Set spending limit** (if using free trial)
   - Prevents accidental charges

**Estimated Monthly Cost:** **$0-5** (may incur small charges for bandwidth over 100 GB or storage over 5 GB)

---

## 3) Automated Deployment with Terraform

### 3.1 Prerequisites

**On Your Local Machine:**
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Install Ansible
sudo apt install ansible -y

# Login to Azure
az login
az account set --subscription "<your-subscription-id>"
```

**Azure Subscription Requirements:**
- Azure subscription (free trial or pay-as-you-go)
- Owner or Contributor role
- No spending limits preventing resource creation

---

### 3.2 Terraform Configuration

**Directory Structure:**
```
infrastructure/azure-free-tier/
├── main.tf                  # Main resources
├── variables.tf             # Input variables
├── outputs.tf               # Outputs (IP addresses, etc.)
├── terraform.tfvars.example # Example variables file
├── provider.tf              # Azure provider config
├── network.tf               # VNet, subnets, NSGs
├── compute.tf               # VMs
├── storage.tf               # Storage account, Key Vault
├── database.tf              # PostgreSQL
└── scripts/
    ├── awx-install.sh       # AWX installation script
    └── cloud-init.yaml      # VM initialization
```

---

### 3.3 Terraform Code

#### **provider.tf**

```hcl
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
  }
  
  # Optional: Store state in Azure Storage (free)
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "sttfstate<random>"
  #   container_name       = "tfstate"
  #   key                  = "migration-demo.tfstate"
  # }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
```

---

#### **variables.tf**

```hcl
variable "prefix" {
  description = "Prefix for all resources"
  type        = string
  default     = "migdemo"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"  # Free tier available in most regions
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Admin password for VMs (use Key Vault in production)"
  type        = string
  sensitive   = true
  # Generate strong password or retrieve from environment
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access AWX and VMs (your office/home IP)"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # ⚠️ Change this to your public IP for security
}

variable "source_domain_fqdn" {
  description = "Source Active Directory domain FQDN"
  type        = string
  default     = "olddomain.local"
}

variable "target_domain_fqdn" {
  description = "Target Active Directory domain FQDN"
  type        = string
  default     = "newdomain.local"
}

variable "auto_shutdown_enabled" {
  description = "Enable auto-shutdown for VMs to save costs"
  type        = bool
  default     = true
}

variable "auto_shutdown_time" {
  description = "Time to auto-shutdown VMs (24-hour format, UTC)"
  type        = string
  default     = "2200"  # 10 PM UTC
}

variable "auto_shutdown_timezone" {
  description = "Timezone for auto-shutdown"
  type        = string
  default     = "UTC"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Identity-Domain-Migration"
    Environment = "Demo"
    CostCenter  = "IT"
    ManagedBy   = "Terraform"
  }
}
```

---

#### **network.tf**

```hcl
# Resource Group
resource "azurerm_resource_group" "migration" {
  name     = "rg-${var.prefix}"
  location = var.location
  tags     = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "migration" {
  name                = "vnet-${var.prefix}"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  address_space       = ["10.200.0.0/16"]
  tags                = var.tags
}

# Subnet: Control Plane (AWX, Postgres)
resource "azurerm_subnet" "control_plane" {
  name                 = "snet-control-plane"
  resource_group_name  = azurerm_resource_group.migration.name
  virtual_network_name = azurerm_virtual_network.migration.name
  address_prefixes     = ["10.200.1.0/24"]
  
  service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
}

# Subnet: Target Workstations
resource "azurerm_subnet" "workstations" {
  name                 = "snet-workstations"
  resource_group_name  = azurerm_resource_group.migration.name
  virtual_network_name = azurerm_virtual_network.migration.name
  address_prefixes     = ["10.200.2.0/24"]
}

# Network Security Group: Control Plane
resource "azurerm_network_security_group" "control_plane" {
  name                = "nsg-control-plane"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  tags                = var.tags
}

# NSG Rule: Allow HTTPS (AWX Web UI)
resource "azurerm_network_security_rule" "allow_https" {
  name                        = "Allow-HTTPS-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.allowed_ip_ranges
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.migration.name
  network_security_group_name = azurerm_network_security_group.control_plane.name
}

# NSG Rule: Allow SSH (for management)
resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "Allow-SSH-Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.allowed_ip_ranges
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.migration.name
  network_security_group_name = azurerm_network_security_group.control_plane.name
}

# NSG Rule: Allow PostgreSQL (from control plane subnet only)
resource "azurerm_network_security_rule" "allow_postgres" {
  name                        = "Allow-Postgres-Inbound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "10.200.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.migration.name
  network_security_group_name = azurerm_network_security_group.control_plane.name
}

# Associate NSG with Control Plane Subnet
resource "azurerm_subnet_network_security_group_association" "control_plane" {
  subnet_id                 = azurerm_subnet.control_plane.id
  network_security_group_id = azurerm_network_security_group.control_plane.id
}

# Network Security Group: Workstations
resource "azurerm_network_security_group" "workstations" {
  name                = "nsg-workstations"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  tags                = var.tags
}

# NSG Rule: Allow RDP (for demo access)
resource "azurerm_network_security_rule" "allow_rdp" {
  name                        = "Allow-RDP-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefixes     = var.allowed_ip_ranges
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.migration.name
  network_security_group_name = azurerm_network_security_group.workstations.name
}

# NSG Rule: Allow WinRM (for Ansible)
resource "azurerm_network_security_rule" "allow_winrm" {
  name                        = "Allow-WinRM-Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["5985", "5986"]
  source_address_prefix       = "10.200.1.0/24"  # Only from control plane
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.migration.name
  network_security_group_name = azurerm_network_security_group.workstations.name
}

# Associate NSG with Workstations Subnet
resource "azurerm_subnet_network_security_group_association" "workstations" {
  subnet_id                 = azurerm_subnet.workstations.id
  network_security_group_id = azurerm_network_security_group.workstations.id
}
```

---

#### **compute.tf**

```hcl
# Public IP for AWX VM
resource "azurerm_public_ip" "awx" {
  name                = "pip-awx-${var.prefix}"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  allocation_method   = "Static"
  sku                 = "Basic"  # Basic is sufficient and cheaper
  tags                = var.tags
}

# Network Interface for AWX VM
resource "azurerm_network_interface" "awx" {
  name                = "nic-awx-${var.prefix}"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  tags                = var.tags
  
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.control_plane.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.200.1.10"
    public_ip_address_id          = azurerm_public_ip.awx.id
  }
}

# AWX Virtual Machine (B1s - FREE TIER)
resource "azurerm_linux_virtual_machine" "awx" {
  name                = "vm-awx-${var.prefix}"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  size                = "Standard_B1s"  # 1 vCPU, 1 GB RAM (FREE for 12 months)
  admin_username      = var.admin_username
  tags                = var.tags
  
  network_interface_ids = [
    azurerm_network_interface.awx.id,
  ]
  
  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")  # Or generate via Terraform
  }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 32  # Minimum size, within free tier
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  # Cloud-init for initial setup
  custom_data = base64encode(templatefile("${path.module}/scripts/cloud-init.yaml", {
    admin_username = var.admin_username
    postgres_host  = azurerm_postgresql_flexible_server.migration.fqdn
    postgres_db    = azurerm_postgresql_flexible_server_database.awx.name
    postgres_user  = azurerm_postgresql_flexible_server.administrator_login
    storage_account = azurerm_storage_account.migration.name
  }))
  
  identity {
    type = "SystemAssigned"
  }
}

# Auto-shutdown schedule (to save hours when not in use)
resource "azurerm_dev_test_global_vm_shutdown_schedule" "awx" {
  count              = var.auto_shutdown_enabled ? 1 : 0
  virtual_machine_id = azurerm_linux_virtual_machine.awx.id
  location           = azurerm_resource_group.migration.location
  enabled            = true
  
  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.auto_shutdown_timezone
  
  notification_settings {
    enabled = false
  }
}

# Public IP for Test Workstation
resource "azurerm_public_ip" "workstation" {
  name                = "pip-workstation-${var.prefix}"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  allocation_method   = "Static"
  sku                 = "Basic"
  tags                = var.tags
}

# Network Interface for Test Workstation
resource "azurerm_network_interface" "workstation" {
  name                = "nic-workstation-${var.prefix}"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  tags                = var.tags
  
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.workstations.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.200.2.10"
    public_ip_address_id          = azurerm_public_ip.workstation.id
  }
}

# Test Workstation VM (B1s Windows - FREE TIER)
resource "azurerm_windows_virtual_machine" "workstation" {
  name                = "vm-test-${var.prefix}"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  size                = "Standard_B1s"  # 1 vCPU, 1 GB RAM (FREE for 12 months)
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  tags                = var.tags
  
  network_interface_ids = [
    azurerm_network_interface.workstation.id,
  ]
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64  # Windows needs more space
  }
  
  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-11"
    sku       = "win11-21h2-pro"
    version   = "latest"
  }
  
  # Enable WinRM for Ansible
  additional_unattend_content {
    setting = "AutoLogon"
    content = "<AutoLogon><Password><Value>${var.admin_password}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.admin_username}</Username></AutoLogon>"
  }
  
  additional_unattend_content {
    setting = "FirstLogonCommands"
    content = file("${path.module}/scripts/winrm-setup.xml")
  }
}

# Auto-shutdown for Workstation
resource "azurerm_dev_test_global_vm_shutdown_schedule" "workstation" {
  count              = var.auto_shutdown_enabled ? 1 : 0
  virtual_machine_id = azurerm_windows_virtual_machine.workstation.id
  location           = azurerm_resource_group.migration.location
  enabled            = true
  
  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.auto_shutdown_timezone
  
  notification_settings {
    enabled = false
  }
}

# Grant AWX VM access to Storage Account (via Managed Identity)
resource "azurerm_role_assignment" "awx_storage" {
  scope                = azurerm_storage_account.migration.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.awx.identity[0].principal_id
}

# Grant AWX VM access to Key Vault
resource "azurerm_role_assignment" "awx_keyvault" {
  scope                = azurerm_key_vault.migration.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.awx.identity[0].principal_id
}
```

---

#### **storage.tf**

```hcl
# Random string for globally unique storage account name
resource "random_string" "storage_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Storage Account for USMT State Store (5 GB FREE)
resource "azurerm_storage_account" "migration" {
  name                     = "st${var.prefix}${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.migration.name
  location                 = azurerm_resource_group.migration.location
  account_tier             = "Standard"
  account_replication_type = "LRS"  # Locally redundant (cheapest)
  
  blob_properties {
    versioning_enabled = true  # Snapshot-like behavior
    
    delete_retention_policy {
      days = 30
    }
    
    # Lifecycle management (auto-delete old USMT stores)
    container_delete_retention_policy {
      days = 30
    }
  }
  
  # Network rules (restrict access)
  network_rules {
    default_action             = "Deny"
    ip_rules                   = var.allowed_ip_ranges
    virtual_network_subnet_ids = [azurerm_subnet.control_plane.id]
    bypass                     = ["AzureServices"]
  }
  
  tags = var.tags
}

# Blob Container for USMT States
resource "azurerm_storage_container" "usmt_states" {
  name                  = "usmt-states"
  storage_account_name  = azurerm_storage_account.migration.name
  container_access_type = "private"
}

# Lifecycle Management Policy (auto-delete after 30 days)
resource "azurerm_storage_management_policy" "cleanup" {
  storage_account_id = azurerm_storage_account.migration.id
  
  rule {
    name    = "delete-old-usmt-stores"
    enabled = true
    
    filters {
      prefix_match = ["usmt-states/"]
      blob_types   = ["blockBlob"]
    }
    
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 30
      }
      snapshot {
        delete_after_days_since_creation_greater_than = 30
      }
      version {
        delete_after_days_since_creation = 30
      }
    }
  }
}

# Get current Azure AD tenant and user
data "azurerm_client_config" "current" {}

# Key Vault for Secrets (10,000 operations/month FREE)
resource "azurerm_key_vault" "migration" {
  name                = "kv-${var.prefix}-${random_string.storage_suffix.result}"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  
  # Use RBAC for access control (modern approach)
  enable_rbac_authorization = true
  
  # Soft-delete (required)
  soft_delete_retention_days = 7
  purge_protection_enabled   = false  # Set to true for production
  
  # Network ACLs
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = var.allowed_ip_ranges
    virtual_network_subnet_ids = [azurerm_subnet.control_plane.id]
  }
  
  tags = var.tags
}

# Grant yourself access to Key Vault (for initial secret population)
resource "azurerm_role_assignment" "keyvault_admin" {
  scope                = azurerm_key_vault.migration.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Example Secret: Domain Admin Credentials (populate after deployment)
resource "azurerm_key_vault_secret" "domain_admin" {
  name         = "domain-admin"
  value        = jsonencode({
    username = "OLDDOMAIN\\Administrator"
    password = "CHANGE_ME_AFTER_DEPLOYMENT"
  })
  key_vault_id = azurerm_key_vault.migration.id
  
  depends_on = [azurerm_role_assignment.keyvault_admin]
}
```

---

#### **database.tf**

```hcl
# Random password for PostgreSQL admin
resource "random_password" "postgres_admin" {
  length  = 16
  special = true
}

# Azure Database for PostgreSQL Flexible Server (B1ms FREE for 12 months)
resource "azurerm_postgresql_flexible_server" "migration" {
  name                = "psql-${var.prefix}-${random_string.storage_suffix.result}"
  resource_group_name = azurerm_resource_group.migration.name
  location            = azurerm_resource_group.migration.location
  
  sku_name   = "B_Standard_B1ms"  # Burstable B1ms (1 vCore, 2 GB RAM) - FREE TIER
  version    = "14"
  storage_mb = 32768  # 32 GB (minimum)
  
  administrator_login    = "pgadmin"
  administrator_password = random_password.postgres_admin.result
  
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false  # Not available in free tier
  
  # Private networking (via delegated subnet) - costs extra
  # For demo, use public access with firewall rules
  
  tags = var.tags
}

# Firewall rule: Allow Azure services
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.migration.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Firewall rule: Allow control plane subnet
resource "azurerm_postgresql_flexible_server_firewall_rule" "control_plane" {
  name             = "AllowControlPlane"
  server_id        = azurerm_postgresql_flexible_server.migration.id
  start_ip_address = "10.200.1.0"
  end_ip_address   = "10.200.1.255"
}

# Firewall rule: Allow your IP (for management)
resource "azurerm_postgresql_flexible_server_firewall_rule" "admin_access" {
  count            = length(var.allowed_ip_ranges)
  name             = "AllowAdminAccess-${count.index}"
  server_id        = azurerm_postgresql_flexible_server.migration.id
  start_ip_address = split("/", var.allowed_ip_ranges[count.index])[0]
  end_ip_address   = split("/", var.allowed_ip_ranges[count.index])[0]
}

# Database for AWX
resource "azurerm_postgresql_flexible_server_database" "awx" {
  name      = "awx"
  server_id = azurerm_postgresql_flexible_server.migration.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Database for Migration Reporting
resource "azurerm_postgresql_flexible_server_database" "migration_reporting" {
  name      = "migration_reporting"
  server_id = azurerm_postgresql_flexible_server.migration.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Store PostgreSQL connection string in Key Vault
resource "azurerm_key_vault_secret" "postgres_connection" {
  name         = "postgres-connection-string"
  value        = "postgresql://pgadmin:${random_password.postgres_admin.result}@${azurerm_postgresql_flexible_server.migration.fqdn}:5432/migration_reporting?sslmode=require"
  key_vault_id = azurerm_key_vault.migration.id
  
  depends_on = [azurerm_role_assignment.keyvault_admin]
}
```

---

#### **outputs.tf**

```hcl
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.migration.name
}

output "awx_public_ip" {
  description = "Public IP address of AWX VM"
  value       = azurerm_public_ip.awx.ip_address
}

output "awx_url" {
  description = "AWX Web UI URL"
  value       = "https://${azurerm_public_ip.awx.ip_address}"
}

output "workstation_public_ip" {
  description = "Public IP address of test workstation"
  value       = azurerm_public_ip.workstation.ip_address
}

output "workstation_rdp" {
  description = "RDP connection string for test workstation"
  value       = "mstsc /v:${azurerm_public_ip.workstation.ip_address}"
}

output "postgres_fqdn" {
  description = "PostgreSQL server FQDN"
  value       = azurerm_postgresql_flexible_server.migration.fqdn
}

output "postgres_admin_username" {
  description = "PostgreSQL admin username"
  value       = azurerm_postgresql_flexible_server.migration.administrator_login
  sensitive   = true
}

output "postgres_admin_password" {
  description = "PostgreSQL admin password"
  value       = random_password.postgres_admin.result
  sensitive   = true
}

output "storage_account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.migration.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Storage account blob endpoint"
  value       = azurerm_storage_account.migration.primary_blob_endpoint
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.migration.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.migration.vault_uri
}

output "ssh_command" {
  description = "SSH command to connect to AWX VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.awx.ip_address}"
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost (within free tier)"
  value       = "$0-5 (within Azure free tier for 12 months)"
}

output "next_steps" {
  description = "Next steps after deployment"
  value       = <<-EOT
    
    ✅ Deployment complete!
    
    Next steps:
    
    1. Access AWX Web UI:
       URL: https://${azurerm_public_ip.awx.ip_address}
       (Initial setup will take ~10 minutes after VM boot)
    
    2. SSH to AWX VM:
       ${output.ssh_command.value}
    
    3. RDP to test workstation:
       ${output.workstation_rdp.value}
       Username: ${var.admin_username}
       Password: <from terraform.tfvars>
    
    4. View PostgreSQL connection details:
       terraform output postgres_admin_password
    
    5. Configure AWX:
       - Create organization
       - Add inventories
       - Import playbooks from Git
    
    6. Update Key Vault secrets:
       az keyvault secret set --vault-name ${azurerm_key_vault.migration.name} --name domain-admin --value '{"username":"DOMAIN\\admin","password":"RealPassword"}'
    
    Cost: $0-5/month (within free tier)
    
    To destroy: terraform destroy
  EOT
}
```

---

### 3.4 Supporting Scripts

#### **scripts/cloud-init.yaml**

```yaml
#cloud-config
package_update: true
package_upgrade: true

packages:
  - docker.io
  - docker-compose
  - python3-pip
  - git
  - curl
  - jq
  - postgresql-client

write_files:
  - path: /opt/awx-install/docker-compose.yml
    content: |
      version: '3'
      services:
        awx_web:
          image: ansible/awx:21.14.0
          container_name: awx_web
          depends_on:
            - awx_postgres
          ports:
            - "80:8052"
            - "443:8053"
          environment:
            DATABASE_HOST: ${postgres_host}
            DATABASE_NAME: ${postgres_db}
            DATABASE_USER: ${postgres_user}
            DATABASE_PASSWORD: ${postgres_password}
            DATABASE_PORT: 5432
            SECRET_KEY: $(openssl rand -base64 32)
          volumes:
            - /opt/awx/projects:/var/lib/awx/projects
            - /opt/awx/job_output:/var/lib/awx/job_output
        
        awx_task:
          image: ansible/awx:21.14.0
          container_name: awx_task
          depends_on:
            - awx_postgres
          environment:
            DATABASE_HOST: ${postgres_host}
            DATABASE_NAME: ${postgres_db}
            DATABASE_USER: ${postgres_user}
            DATABASE_PASSWORD: ${postgres_password}
            DATABASE_PORT: 5432
          volumes:
            - /opt/awx/projects:/var/lib/awx/projects
            - /opt/awx/job_output:/var/lib/awx/job_output
  
  - path: /opt/awx-install/install.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -e
      
      echo "Installing AWX..."
      
      # Create directories
      mkdir -p /opt/awx/projects /opt/awx/job_output
      
      # Start Docker services
      systemctl enable docker
      systemctl start docker
      
      # Install Docker Compose
      curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      chmod +x /usr/local/bin/docker-compose
      
      # Start AWX
      cd /opt/awx-install
      docker-compose up -d
      
      # Wait for AWX to be ready
      echo "Waiting for AWX to start (this may take 5-10 minutes)..."
      sleep 60
      
      # Create initial admin user (via AWX CLI)
      docker exec awx_task awx-manage createsuperuser --username admin --email admin@example.com --noinput || true
      docker exec awx_task awx-manage update_password --username admin --password admin || true
      
      echo "AWX installation complete!"
      echo "Access AWX at: http://$(curl -s ifconfig.me)"
      echo "Username: admin"
      echo "Password: admin (CHANGE THIS IMMEDIATELY)"

runcmd:
  - usermod -aG docker ${admin_username}
  - /opt/awx-install/install.sh > /var/log/awx-install.log 2>&1
  - echo "cloud-init complete" >> /var/log/cloud-init-done.log

final_message: "AWX installation started. Check /var/log/awx-install.log for progress."
```

#### **scripts/winrm-setup.xml**

```xml
<FirstLogonCommands>
  <SynchronousCommand>
    <CommandLine>powershell.exe -ExecutionPolicy Bypass -Command "Enable-PSRemoting -Force; Set-Item wsman:\localhost\client\trustedhosts * -Force; Set-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' -RemoteAddress Any"</CommandLine>
    <Description>Enable WinRM for Ansible</Description>
    <Order>1</Order>
  </SynchronousCommand>
  <SynchronousCommand>
    <CommandLine>powershell.exe -ExecutionPolicy Bypass -Command "New-NetFirewallRule -Name 'WinRM-HTTPS' -DisplayName 'WinRM HTTPS' -Protocol TCP -LocalPort 5986 -Action Allow"</CommandLine>
    <Description>Open WinRM HTTPS port</Description>
    <Order>2</Order>
  </SynchronousCommand>
</FirstLogonCommands>
```

---

### 3.5 terraform.tfvars.example

```hcl
# Copy this file to terraform.tfvars and customize

prefix   = "migdemo"
location = "eastus"

admin_username = "azureadmin"
admin_password = "P@ssw0rd123!ComplexPassword"  # Change this!

# Your public IP (for security)
# Find yours at: curl ifconfig.me
allowed_ip_ranges = ["203.0.113.0/32"]  # Replace with YOUR public IP

source_domain_fqdn = "olddomain.local"
target_domain_fqdn = "newdomain.local"

auto_shutdown_enabled = true
auto_shutdown_time    = "2200"  # 10 PM UTC
auto_shutdown_timezone = "UTC"

tags = {
  Project     = "Identity-Domain-Migration-Demo"
  Environment = "Demo"
  CostCenter  = "IT-Lab"
  ManagedBy   = "Terraform"
  Owner       = "yourname@example.com"
}
```

---

### 3.6 Guacamole Bastion Configuration

#### **Guacamole VM (compute.tf addition)**

```hcl
# Public IP for Guacamole Bastion
resource "azurerm_public_ip" "guacamole" {
  name                = "pip-guacamole-${var.prefix}"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  allocation_method   = "Static"
  sku                 = "Basic"
  tags                = var.tags
}

# Network Interface for Guacamole
resource "azurerm_network_interface" "guacamole" {
  name                = "nic-guacamole-${var.prefix}"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  tags                = var.tags
  
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.bastion.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.200.0.4"
    public_ip_address_id          = azurerm_public_ip.guacamole.id
  }
}

# Guacamole Bastion VM (B1s - FREE TIER)
resource "azurerm_linux_virtual_machine" "guacamole" {
  name                = "vm-guacamole-${var.prefix}"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  size                = "Standard_B1s"  # 1 vCPU, 1 GB RAM (FREE for 12 months)
  admin_username      = var.admin_username
  tags                = var.tags
  
  network_interface_ids = [
    azurerm_network_interface.guacamole.id,
  ]
  
  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 32
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  # Cloud-init for Guacamole installation
  custom_data = base64encode(templatefile("${path.module}/scripts/guacamole-cloud-init.yaml", {
    admin_username     = var.admin_username
    postgres_host      = azurerm_postgresql_flexible_server.migration.fqdn
    postgres_user      = azurerm_postgresql_flexible_server.migration.administrator_login
    postgres_password  = random_password.postgres_admin.result
    awx_host           = "10.200.1.10"
    postgres_vm_host   = "10.200.1.20"
    workstation_host   = "10.200.2.10"
    resource_group     = azurerm_resource_group.migration.name
    nsg_name           = azurerm_network_security_group.bastion.name
    nsg_rule_name      = azurerm_network_security_rule.allow_https_dynamic.name
    subscription_id    = data.azurerm_client_config.current.subscription_id
  }))
  
  identity {
    type = "SystemAssigned"
  }
}

# Grant Guacamole VM permission to update NSG rules
resource "azurerm_role_assignment" "guacamole_nsg" {
  scope                = azurerm_network_security_group.bastion.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_linux_virtual_machine.guacamole.identity[0].principal_id
}

# Auto-shutdown for Guacamole
resource "azurerm_dev_test_global_vm_shutdown_schedule" "guacamole" {
  count              = var.auto_shutdown_enabled ? 1 : 0
  virtual_machine_id = azurerm_linux_virtual_machine.guacamole.id
  location           = azurerm_resource_group.migration.location
  enabled            = true
  
  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.auto_shutdown_timezone
  
  notification_settings {
    enabled = false
  }
}
```

#### **Bastion Subnet and NSG (network.tf addition)**

```hcl
# Subnet: Bastion (DMZ)
resource "azurerm_subnet" "bastion" {
  name                 = "snet-bastion"
  resource_group_name  = azurerm_resource_group.migration.name
  virtual_network_name = azurerm_virtual_network.migration.name
  address_prefixes     = ["10.200.0.0/28"]  # Only 16 IPs needed
  
  service_endpoints = []  # No service endpoints for DMZ
}

# Network Security Group: Bastion
resource "azurerm_network_security_group" "bastion" {
  name                = "nsg-bastion"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  tags                = var.tags
}

# NSG Rule: Allow HTTPS from dynamic IP (updated by script)
resource "azurerm_network_security_rule" "allow_https_dynamic" {
  name                        = "Allow-HTTPS-Dynamic-IP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "0.0.0.0/32"  # Placeholder, updated by script
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.migration.name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

# NSG Rule: Allow SSH from dynamic IP (for emergency access)
resource "azurerm_network_security_rule" "allow_ssh_dynamic" {
  name                        = "Allow-SSH-Dynamic-IP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "0.0.0.0/32"  # Placeholder, updated by script
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.migration.name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

# NSG Rule: Deny all other inbound
resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "Deny-All-Inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.migration.name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

# Associate NSG with Bastion Subnet
resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}
```

#### **Remove Public IPs from Other VMs (security improvement)**

```hcl
# UPDATE: Remove these resources from compute.tf
# - azurerm_public_ip.awx  (DELETE)
# - azurerm_public_ip.workstation  (DELETE)

# UPDATE: Remove public_ip_address_id from network interfaces
resource "azurerm_network_interface" "awx" {
  # ... other config ...
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.control_plane.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.200.1.10"
    # REMOVE: public_ip_address_id = azurerm_public_ip.awx.id
  }
}

resource "azurerm_network_interface" "workstation" {
  # ... other config ...
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.workstations.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.200.2.10"
    # REMOVE: public_ip_address_id = azurerm_public_ip.workstation.id
  }
}
```

#### **Guacamole PostgreSQL Database (database.tf addition)**

```hcl
# Database for Guacamole
resource "azurerm_postgresql_flexible_server_database" "guacamole" {
  name      = "guacamole"
  server_id = azurerm_postgresql_flexible_server.migration.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Firewall rule: Allow bastion subnet
resource "azurerm_postgresql_flexible_server_firewall_rule" "bastion" {
  name             = "AllowBastion"
  server_id        = azurerm_postgresql_flexible_server.migration.id
  start_ip_address = "10.200.0.0"
  end_ip_address   = "10.200.0.15"
}
```

---

### 3.7 Guacamole Cloud-Init Script

**scripts/guacamole-cloud-init.yaml:**

```yaml
#cloud-config
package_update: true
package_upgrade: true

packages:
  - docker.io
  - docker-compose
  - nginx
  - certbot
  - python3-certbot-nginx
  - curl
  - jq
  - postgresql-client
  - python3-pip

write_files:
  # Guacamole Docker Compose
  - path: /opt/guacamole/docker-compose.yml
    content: |
      version: '3'
      services:
        guacd:
          image: guacamole/guacd:latest
          container_name: guacd
          restart: always
          volumes:
            - /opt/guacamole/drive:/drive
            - /opt/guacamole/record:/record
        
        guacamole:
          image: guacamole/guacamole:latest
          container_name: guacamole
          restart: always
          ports:
            - "8080:8080"
          environment:
            GUACD_HOSTNAME: guacd
            GUACD_PORT: 4822
            POSTGRES_HOSTNAME: ${postgres_host}
            POSTGRES_DATABASE: guacamole
            POSTGRES_USER: ${postgres_user}
            POSTGRES_PASSWORD: ${postgres_password}
          depends_on:
            - guacd
          volumes:
            - /opt/guacamole/extensions:/extensions
  
  # Nginx configuration (HTTPS reverse proxy)
  - path: /etc/nginx/sites-available/guacamole
    content: |
      server {
          listen 443 ssl http2;
          server_name _;
          
          # Self-signed certificate (replace with Let's Encrypt in production)
          ssl_certificate /etc/ssl/certs/guacamole-selfsigned.crt;
          ssl_certificate_key /etc/ssl/private/guacamole-selfsigned.key;
          
          ssl_protocols TLSv1.2 TLSv1.3;
          ssl_ciphers HIGH:!aNULL:!MD5;
          ssl_prefer_server_ciphers on;
          
          location / {
              proxy_pass http://localhost:8080/guacamole/;
              proxy_buffering off;
              proxy_http_version 1.1;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection $http_connection;
              proxy_cookie_path /guacamole/ /;
              access_log off;
          }
      }
      
      server {
          listen 80;
          server_name _;
          return 301 https://$host$request_uri;
      }
  
  # Dynamic IP update script
  - path: /usr/local/bin/update-my-ip.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -e
      
      # Get current public IP
      MY_IP=$(curl -s https://api.ipify.org)
      echo "[$(date)] Detected public IP: $MY_IP"
      
      # Azure CLI login using managed identity
      az login --identity
      
      # Update NSG rule with current IP
      az network nsg rule update \
        --resource-group "${resource_group}" \
        --nsg-name "${nsg_name}" \
        --name "${nsg_rule_name}" \
        --source-address-prefixes "$MY_IP/32"
      
      echo "[$(date)] NSG rule updated successfully"
      
      # Also update SSH rule
      az network nsg rule update \
        --resource-group "${resource_group}" \
        --nsg-name "${nsg_name}" \
        --name "Allow-SSH-Dynamic-IP" \
        --source-address-prefixes "$MY_IP/32"
      
      echo "[$(date)] SSH rule updated successfully"
      
      # Optional: Send notification
      # curl -X POST "https://ntfy.sh/migration-demo" -d "IP updated to $MY_IP"
  
  # Cron job for periodic IP updates (every 5 minutes)
  - path: /etc/cron.d/update-ip
    content: |
      */5 * * * * root /usr/local/bin/update-my-ip.sh >> /var/log/update-ip.log 2>&1
  
  # Guacamole database initialization script
  - path: /opt/guacamole/init-guacamole-db.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -e
      
      echo "Initializing Guacamole database..."
      
      # Download Guacamole schema
      docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgres > /tmp/initdb.sql
      
      # Initialize database
      PGPASSWORD=${postgres_password} psql -h ${postgres_host} -U ${postgres_user} -d guacamole -f /tmp/initdb.sql
      
      # Create default admin user (username: guacadmin, password: guacadmin)
      # User should change this immediately after first login
      
      echo "Guacamole database initialized successfully"
  
  # Guacamole connections setup script
  - path: /opt/guacamole/setup-connections.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # This script adds pre-configured connections to Guacamole
      # Run after initial setup and login
      
      echo "Setting up Guacamole connections..."
      echo "NOTE: Configure these via Guacamole Web UI after first login:"
      echo ""
      echo "1. AWX (SSH)"
      echo "   - Protocol: SSH"
      echo "   - Hostname: ${awx_host}"
      echo "   - Port: 22"
      echo "   - Username: ${admin_username}"
      echo "   - Private key: Upload your SSH key"
      echo ""
      echo "2. PostgreSQL (SSH)"
      echo "   - Protocol: SSH"
      echo "   - Hostname: ${postgres_vm_host}"
      echo "   - Port: 22"
      echo "   - Username: ${admin_username}"
      echo "   - Private key: Upload your SSH key"
      echo ""
      echo "3. Test Workstation (RDP)"
      echo "   - Protocol: RDP"
      echo "   - Hostname: ${workstation_host}"
      echo "   - Port: 3389"
      echo "   - Username: ${admin_username}"
      echo "   - Password: (from Key Vault)"
      echo "   - Security: NLA"
      echo "   - Ignore server certificate: Yes"

runcmd:
  # Install Azure CLI
  - curl -sL https://aka.ms/InstallAzureCLIDeb | bash
  
  # Generate self-signed certificate
  - openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/guacamole-selfsigned.key -out /etc/ssl/certs/guacamole-selfsigned.crt -subj "/C=US/ST=State/L=City/O=Organization/CN=guacamole"
  
  # Configure Nginx
  - rm /etc/nginx/sites-enabled/default
  - ln -s /etc/nginx/sites-available/guacamole /etc/nginx/sites-enabled/
  - systemctl enable nginx
  - systemctl restart nginx
  
  # Create Guacamole directories
  - mkdir -p /opt/guacamole/drive /opt/guacamole/record /opt/guacamole/extensions
  
  # Enable and start Docker
  - systemctl enable docker
  - systemctl start docker
  
  # Install Docker Compose
  - curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  - chmod +x /usr/local/bin/docker-compose
  
  # Initialize Guacamole database
  - sleep 30  # Wait for PostgreSQL to be ready
  - /opt/guacamole/init-guacamole-db.sh || echo "Database might already be initialized"
  
  # Start Guacamole
  - cd /opt/guacamole && docker-compose up -d
  
  # Wait for Guacamole to start
  - sleep 60
  
  # Update NSG with current IP
  - /usr/local/bin/update-my-ip.sh
  
  # Display connection info
  - echo "Guacamole is ready!"
  - echo "Access at: https://$(curl -s ifconfig.me)"
  - echo "Default login: guacadmin / guacadmin (CHANGE THIS!)"

final_message: "Guacamole bastion host is ready. Access via https://PUBLIC_IP"
```

---

### 3.8 Dynamic IP Update Script (Client-Side)

**For users with dynamic home/office IPs, run this locally before accessing Guacamole:**

**scripts/update-azure-nsg-ip.sh** (run on your local machine):

```bash
#!/bin/bash
# Update Azure NSG to allow your current public IP
# Usage: ./update-azure-nsg-ip.sh

set -e

# Configuration (update these)
RESOURCE_GROUP="rg-migdemo"
NSG_NAME="nsg-bastion"
HTTPS_RULE_NAME="Allow-HTTPS-Dynamic-IP"
SSH_RULE_NAME="Allow-SSH-Dynamic-IP"

# Get your current public IP
echo "Detecting your public IP..."
MY_IP=$(curl -s https://api.ipify.org)

if [ -z "$MY_IP" ]; then
  echo "Error: Could not detect public IP"
  exit 1
fi

echo "Your public IP: $MY_IP"

# Check if already logged in to Azure
if ! az account show &>/dev/null; then
  echo "Logging in to Azure..."
  az login
fi

# Update HTTPS rule
echo "Updating NSG rule for HTTPS access..."
az network nsg rule update \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$NSG_NAME" \
  --name "$HTTPS_RULE_NAME" \
  --source-address-prefixes "$MY_IP/32"

# Update SSH rule
echo "Updating NSG rule for SSH access..."
az network nsg rule update \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$NSG_NAME" \
  --name "$SSH_RULE_NAME" \
  --source-address-prefixes "$MY_IP/32"

echo ""
echo "✅ NSG rules updated successfully!"
echo "You can now access Guacamole at: https://$(az network public-ip show --resource-group $RESOURCE_GROUP --name pip-guacamole-migdemo --query ipAddress -o tsv)"
echo ""
echo "Note: Your IP will be re-verified every 5 minutes by the Guacamole VM itself."
```

**Make it executable:**
```bash
chmod +x scripts/update-azure-nsg-ip.sh
```

**Windows version (PowerShell):**

**scripts/Update-AzureNsgIp.ps1:**

```powershell
# Update Azure NSG to allow your current public IP
# Usage: .\Update-AzureNsgIp.ps1

param(
    [string]$ResourceGroup = "rg-migdemo",
    [string]$NsgName = "nsg-bastion",
    [string]$HttpsRuleName = "Allow-HTTPS-Dynamic-IP",
    [string]$SshRuleName = "Allow-SSH-Dynamic-IP"
)

Write-Host "Detecting your public IP..." -ForegroundColor Cyan
$MyIP = (Invoke-RestMethod -Uri "https://api.ipify.org").Trim()

if ([string]::IsNullOrEmpty($MyIP)) {
    Write-Host "Error: Could not detect public IP" -ForegroundColor Red
    exit 1
}

Write-Host "Your public IP: $MyIP" -ForegroundColor Green

# Check if logged in to Azure
try {
    $null = Get-AzContext -ErrorAction Stop
} catch {
    Write-Host "Logging in to Azure..." -ForegroundColor Yellow
    Connect-AzAccount
}

# Update HTTPS rule
Write-Host "Updating NSG rule for HTTPS access..." -ForegroundColor Cyan
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroup -Name $NsgName
$httpsRule = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name $HttpsRuleName
$httpsRule.SourceAddressPrefix = "$MyIP/32"
Set-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name $HttpsRuleName `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
    -SourceAddressPrefix "$MyIP/32" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 443
$nsg | Set-AzNetworkSecurityGroup

# Update SSH rule
Write-Host "Updating NSG rule for SSH access..." -ForegroundColor Cyan
$sshRule = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name $SshRuleName
$sshRule.SourceAddressPrefix = "$MyIP/32"
Set-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name $SshRuleName `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
    -SourceAddressPrefix "$MyIP/32" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 22
$nsg | Set-AzNetworkSecurityGroup

Write-Host ""
Write-Host "✅ NSG rules updated successfully!" -ForegroundColor Green
$publicIp = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroup -Name "pip-guacamole-migdemo"
Write-Host "You can now access Guacamole at: https://$($publicIp.IpAddress)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: Your IP will be re-verified every 5 minutes by the Guacamole VM itself." -ForegroundColor Yellow
```

---

### 3.9 Updated Outputs (outputs.tf)

```hcl
output "guacamole_public_ip" {
  description = "Guacamole bastion public IP"
  value       = azurerm_public_ip.guacamole.ip_address
}

output "guacamole_url" {
  description = "Guacamole web UI URL"
  value       = "https://${azurerm_public_ip.guacamole.ip_address}"
}

output "guacamole_default_credentials" {
  description = "Guacamole default login (CHANGE IMMEDIATELY)"
  value       = "Username: guacadmin | Password: guacadmin"
  sensitive   = true
}

output "awx_url_via_guacamole" {
  description = "Access AWX via Guacamole"
  value       = "SSH to 10.200.1.10 via Guacamole, then browse to http://localhost"
}

output "update_ip_command" {
  description = "Command to update your IP in NSG"
  value       = "./scripts/update-azure-nsg-ip.sh"
}

output "next_steps" {
  description = "Next steps after deployment"
  value       = <<-EOT
    
    ✅ Deployment complete!
    
    Next steps:
    
    1. Update NSG with your current IP:
       Linux/Mac: ./scripts/update-azure-nsg-ip.sh
       Windows:   .\scripts\Update-AzureNsgIp.ps1
    
    2. Access Guacamole Bastion:
       URL: ${output.guacamole_url.value}
       Username: guacadmin
       Password: guacadmin (CHANGE THIS IMMEDIATELY!)
    
    3. Configure connections in Guacamole:
       - AWX: SSH to 10.200.1.10
       - PostgreSQL: SSH to 10.200.1.20
       - Test Workstation: RDP to 10.200.2.10
    
    4. Access AWX Web UI:
       - Connect to AWX via Guacamole SSH
       - In SSH session: curl http://localhost
       - Or set up SSH tunnel via Guacamole
    
    5. All VMs are private (no public IPs except Guacamole)
       - Enhanced security
       - Access only via Guacamole bastion
    
    Cost: $0 (within free tier for 12 months)
    
    Note: Your IP is auto-updated every 5 minutes by Guacamole VM
  EOT
}
```

---

## 4) Deployment Steps

### 4.1 Initial Setup

```bash
# Clone the repository (assuming you've created it)
git clone https://github.com/yourorg/migration-automation.git
cd migration-automation

# Checkout Azure free tier branch
git checkout platform/azure

# Navigate to Terraform directory
cd infrastructure/azure-free-tier

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Add your IP, passwords, etc.
```

---

### 4.2 Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment (review resources)
terraform plan

# Apply (deploy resources)
terraform apply

# Save outputs
terraform output -json > outputs.json
terraform output awx_url
terraform output workstation_rdp
terraform output postgres_admin_password
```

**Expected Duration:** 10-15 minutes

---

### 4.3 Verify Deployment

```bash
# Get AWX public IP
AWX_IP=$(terraform output -raw awx_public_ip)

# Check if AWX VM is running
ssh azureadmin@$AWX_IP "docker ps"

# Check AWX installation log
ssh azureadmin@$AWX_IP "tail -f /var/log/awx-install.log"

# Test AWX Web UI access
curl -k https://$AWX_IP

# RDP to test workstation
WORKSTATION_IP=$(terraform output -raw workstation_public_ip)
echo "RDP to: $WORKSTATION_IP"
```

---

### 4.4 Initial AWX Configuration

**Access AWX Web UI:**
1. Open browser: `https://<awx_public_ip>`
2. Accept self-signed certificate warning
3. Login:
   - Username: `admin`
   - Password: `admin` (CHANGE IMMEDIATELY)

**Create Organization:**
```
Settings → Organizations → Add
Name: Migration Demo
Description: Identity & Domain Migration Demo
```

**Add Credentials:**
```
Resources → Credentials → Add

1. Azure Credential:
   Type: Microsoft Azure Resource Manager
   Name: Azure Demo
   Subscription ID: <from Azure>
   Client ID: <from managed identity>

2. Domain Admin:
   Type: Machine
   Name: Source Domain Admin
   Username: OLDDOMAIN\Administrator
   Password: <from Key Vault>

3. Target Domain Admin:
   Type: Machine
   Name: Target Domain Admin
   Username: NEWDOMAIN\Administrator
   Password: <from Key Vault>
```

**Add Inventory:**
```
Resources → Inventories → Add
Name: Demo Inventory
Organization: Migration Demo

Add Host:
  Name: vm-test-migdemo
  Variables:
    ansible_host: 10.200.2.10
    ansible_connection: winrm
    ansible_winrm_transport: ntlm
    ansible_winrm_server_cert_validation: ignore
```

**Import Playbooks:**
```
Resources → Projects → Add
Name: Migration Playbooks
Organization: Migration Demo
SCM Type: Git
SCM URL: https://github.com/yourorg/migration-automation.git
SCM Branch: platform/azure
SCM Update Options: [x] Update on launch
```

---

### 4.5 Post-Deployment Configuration

**Update Key Vault Secrets:**
```bash
# Get Key Vault name
KV_NAME=$(terraform output -raw key_vault_name)

# Update domain admin credentials (real values)
az keyvault secret set \
  --vault-name $KV_NAME \
  --name domain-admin \
  --value '{"username":"OLDDOMAIN\\Administrator","password":"RealPassword123"}'

# Add service account credentials
az keyvault secret set \
  --vault-name $KV_NAME \
  --name service-account-migration \
  --value '{"username":"OLDDOMAIN\\svc_migration","password":"ServicePass123"}'
```

**Configure Azure Storage Access from Ansible:**
```bash
# Get storage account key
STORAGE_KEY=$(az storage account keys list \
  --resource-group $(terraform output -raw resource_group_name) \
  --account-name $(terraform output -raw storage_account_name) \
  --query '[0].value' -o tsv)

# Store in Key Vault
az keyvault secret set \
  --vault-name $KV_NAME \
  --name storage-account-key \
  --value "$STORAGE_KEY"
```

---

## 5) Running a Demo Migration

### 5.1 Prepare Test Workstation

**RDP to test workstation:**
```powershell
# On test workstation (via RDP)

# Join to source domain (simulate existing environment)
Add-Computer -DomainName "olddomain.local" -Credential (Get-Credential) -Restart

# After reboot, login as domain user
# Create test user profile
runas /user:OLDDOMAIN\testuser cmd

# Create some test data
New-Item -Path "C:\Users\testuser\Desktop\test-migration-file.txt" -Value "This file should migrate"
```

---

### 5.2 Run Discovery Playbook

**In AWX Web UI:**
```
1. Templates → Add → Job Template
   Name: 00 - Discovery
   Inventory: Demo Inventory
   Project: Migration Playbooks
   Playbook: playbooks/00a_discovery_ad.yml
   Credentials: Source Domain Admin

2. Launch Job
   
3. Review output:
   - Detected users
   - Detected computers
   - Detected groups
```

---

### 5.3 Run Machine Migration

```
1. Templates → Add → Job Template
   Name: 20 - Migrate Machine (USMT)
   Inventory: Demo Inventory
   Project: Migration Playbooks
   Playbook: playbooks/20_machine_move_usmt.yml
   Credentials: Source Domain Admin, Target Domain Admin, Azure
   Extra Variables:
     target_domain: newdomain.local
     target_ou: "OU=Migrated,DC=newdomain,DC=local"

2. Launch Job

3. Monitor progress (15-20 minutes for B1s VM)
   - USMT Capture
   - Domain disjoin
   - Domain join (target)
   - USMT Restore
   - Validation
```

---

### 5.4 Validate Migration

**In AWX:**
- Check job output for errors
- Verify all tasks completed successfully

**On test workstation:**
```powershell
# Verify domain membership
(Get-WmiObject Win32_ComputerSystem).Domain
# Should show: newdomain.local

# Verify user profile migrated
Test-Path "C:\Users\testuser\Desktop\test-migration-file.txt"
# Should return: True

# Verify SID history
whoami /user
# Should show SID from olddomain
```

---

## 6) Cost Monitoring and Optimization

### 6.1 Monitor Azure Costs

```bash
# Check current month costs
az consumption usage list \
  --start-date $(date -u -d '30 days ago' '+%Y-%m-%dT%H:%M:%SZ') \
  --end-date $(date -u '+%Y-%m-%dT%H:%M:%SZ') \
  --query "[?contains(instanceName, 'migdemo')].{Service:meterCategory, Cost:pretaxCost}" \
  --output table

# Set up budget alert (Azure Portal)
# Cost Management → Budgets → Add
# Budget: $10/month
# Alert: 80% of budget
```

---

### 6.2 Cost Optimization Tips

**To Stay at $0:**

1. ✅ **Use auto-shutdown** (already configured)
   ```bash
   # Manually stop VMs when not in use
   az vm deallocate --resource-group rg-migdemo --name vm-awx-migdemo
   az vm deallocate --resource-group rg-migdemo --name vm-test-migdemo
   
   # Start when needed
   az vm start --resource-group rg-migdemo --name vm-awx-migdemo
   ```

2. ✅ **Delete after demo** (if one-time use)
   ```bash
   terraform destroy
   # Confirm: yes
   ```

3. ✅ **Keep storage under 5 GB**
   ```bash
   # Check storage usage
   az storage blob list \
     --account-name $(terraform output -raw storage_account_name) \
     --container-name usmt-states \
     --query "sum([].properties.contentLength)" \
     --output tsv | awk '{print $1/1024/1024/1024 " GB"}'
   ```

4. ✅ **Monitor free tier hours**
   ```bash
   # B1s VMs: 750 hours/month free
   # If running 24/7: 720 hours/month (within limit)
   # If running 2 VMs: 1440 hours/month (690 hours over limit = ~$15 charge)
   
   # Solution: Use auto-shutdown or manual stop when not in use
   ```

---

### 6.3 What's NOT Free

| Resource | Cost | Mitigation |
|----------|------|------------|
| **VPN Gateway** | $27/month | ❌ Don't deploy (use public IPs) |
| **B1s VM hours over 750** | ~$0.01/hour | ✅ Auto-shutdown, manual stop |
| **Storage over 5 GB** | $0.02/GB/month | ✅ Auto-delete old USMT stores |
| **Bandwidth over 100 GB** | $0.087/GB | ✅ Test locally, minimize transfers |
| **Premium SSD disks** | $10-20/disk | ✅ Use Standard SSD (free tier) |

---

## 7) Cleanup

### 7.1 Destroy Infrastructure

```bash
# Navigate to Terraform directory
cd infrastructure/azure-free-tier

# Destroy all resources
terraform destroy

# Confirm deletion
# Enter: yes

# Verify deletion
az group list --query "[?contains(name, 'migdemo')]" --output table
# Should return empty
```

**Duration:** 5-10 minutes

---

### 7.2 Manual Cleanup (if Terraform fails)

```bash
# Delete resource group (deletes all resources inside)
az group delete --name rg-migdemo --yes --no-wait

# Check for orphaned resources
az resource list --query "[?contains(name, 'migdemo')]" --output table

# Delete orphaned resources manually
az resource delete --ids <resource-id>
```

---

## 8) Troubleshooting

### 8.1 AWX Not Accessible

**Symptom:** Cannot access `https://<awx-ip>`

**Solutions:**
```bash
# Check VM status
az vm get-instance-view --resource-group rg-migdemo --name vm-awx-migdemo --query "instanceView.statuses[1]"

# SSH to VM and check Docker
ssh azureadmin@<awx-ip>
docker ps
tail -f /var/log/awx-install.log

# Check NSG rules
az network nsg rule list --resource-group rg-migdemo --nsg-name nsg-control-plane --output table

# Verify your IP is allowed
curl ifconfig.me
# Add your IP to terraform.tfvars allowed_ip_ranges and re-apply
```

---

### 8.2 PostgreSQL Connection Failed

**Symptom:** AWX can't connect to PostgreSQL

**Solutions:**
```bash
# Check PostgreSQL firewall rules
az postgres flexible-server firewall-rule list \
  --resource-group rg-migdemo \
  --name psql-migdemo-<suffix> \
  --output table

# Test connection from AWX VM
ssh azureadmin@<awx-ip>
psql "postgresql://pgadmin:<password>@<postgres-fqdn>:5432/awx?sslmode=require"

# Check PostgreSQL logs
az postgres flexible-server server-logs list \
  --resource-group rg-migdemo \
  --name psql-migdemo-<suffix>
```

---

### 8.3 Terraform Deployment Failed

**Common Issues:**

1. **Quota exceeded:**
   ```
   Error: Insufficient regional vCPU quota
   
   Solution:
   - Request quota increase (Azure Portal → Quotas)
   - Or deploy in different region
   ```

2. **Name already exists:**
   ```
   Error: Storage account name already exists
   
   Solution:
   - Change prefix in terraform.tfvars
   - Or manually delete old storage account
   ```

3. **Permission denied:**
   ```
   Error: Authorization failed
   
   Solution:
   - Verify Azure login: az account show
   - Verify role: az role assignment list --assignee <your-email>
   - Ensure you have Owner or Contributor role
   ```

---

## 9) Next Steps

### After Demo Success

**Option A: Scale to Tier 2 (Production)**
```bash
# Checkout Tier 2 branch
git checkout platform/azure

# Navigate to Tier 2 Terraform
cd infrastructure/azure-tier2

# Deploy production infrastructure (not free tier)
terraform apply
```

**Option B: Keep Demo, Add Features**
- Deploy more test workstations
- Add Linux server migration
- Test SQL Server migration
- Integrate with Entra ID

**Option C: Migrate to Different Platform**
- Export configuration
- Checkout vSphere branch
- Deploy on-prem (see vSphere guide)

---

## 10) Summary

### What You Get for $0-5/Month

✅ **Control Plane:**
- AWX (Ansible Tower) on B1s Linux VM
- PostgreSQL database (Burstable B1ms)
- Azure Blob storage for USMT states (5 GB)
- Azure Key Vault for secrets

✅ **Test Environment:**
- 1x Windows 11 Pro VM (B1s)
- Simulates production migration

✅ **Automation:**
- Fully deployed via Terraform
- AWX auto-installs via cloud-init
- Auto-shutdown to save hours

✅ **Security:**
- Network security groups (firewall)
- Private networking
- Azure AD authentication
- Key Vault for secrets

### Limitations (Free Tier)

❌ **Scale:** B1s VMs are slow (1 vCPU, 1 GB RAM)
❌ **Storage:** 5 GB blob storage limit
❌ **Networking:** No VPN Gateway (public IPs only)
❌ **HA:** No high availability (single VMs)
❌ **Duration:** Free tier expires after 12 months

### Perfect For

✅ Proof of concept / demo
✅ Learning the platform
✅ Testing playbooks
✅ Small-scale pilot (1-10 machines)
✅ Budget-constrained environments

### NOT Recommended For

❌ Production migrations (>100 machines)
❌ Mission-critical workloads
❌ High-performance requirements
❌ Long-term operations (>12 months)

---

**Next Document:** `docs/19_VSPHERE_IMPLEMENTATION.md` (for on-prem/VMware deployments)

---

**END OF DOCUMENT**

