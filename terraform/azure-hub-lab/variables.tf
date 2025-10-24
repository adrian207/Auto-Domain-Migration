variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "vnet_cidr" {
  description = "Virtual network CIDR"
  type        = string
  default     = "10.30.0.0/16"
}

variable "subnet_cidrs" {
  description = "Subnet CIDRs"
  type        = map(string)
  default = {
    source = "10.30.1.0/24"
    target = "10.30.2.0/24"
    mgmt   = "10.30.3.0/24"
  }
}

variable "storage_account_name" {
  description = "Storage account for replication"
  type        = string
  default     = "srvmsreplication"
}

variable "admin_username" {
  description = "Default admin username"
  type        = string
  default     = "migrate"
}

variable "windows_admin_password" {
  description = "Password for Windows VMs"
  type        = string
  default     = "ChangeM3!Passw0rd"
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7exampleplaceholderkeyforvalidation migrate@example.com"
}

variable "servers" {
  description = "Server definitions"
  type = list(object({
    name   = string
    role   = string
    size   = string
    image  = string
    subnet = string
  }))
  default = [
    {
      name   = "source-linux"
      role   = "source"
      size   = "Standard_DS2_v2"
      image  = "Canonical/UbuntuServer/22_04-lts"
      subnet = "source"
    },
    {
      name   = "target-linux"
      role   = "target"
      size   = "Standard_DS2_v2"
      image  = "Canonical/UbuntuServer/22_04-lts"
      subnet = "target"
    },
    {
      name   = "source-windows"
      role   = "windows"
      size   = "Standard_D4s_v5"
      image  = "MicrosoftWindowsServer/WindowsServer/2022-datacenter"
      subnet = "source"
    },
    {
      name   = "target-windows"
      role   = "windows"
      size   = "Standard_D4s_v5"
      image  = "MicrosoftWindowsServer/WindowsServer/2022-datacenter"
      subnet = "target"
    }
  ]
}

variable "log_retention_days" {
  type        = number
  default     = 30
  description = "Log Analytics retention"
}

variable "tags" {
  type        = map(string)
  default = {
    project = "server-migration"
    owner   = "automation"
  }
}
