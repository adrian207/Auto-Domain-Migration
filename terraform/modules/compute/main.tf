terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

variable "platform" {
  type        = string
  description = "Target platform (aws|azure|gcp)."
}

variable "instances" {
  description = "List of instance definitions."
  type = list(object({
    name          = string
    role          = string
    instance_type = string
    image         = string
    subnet_id     = string
  }))
}

variable "admin_username" {
  type        = string
  description = "Default admin username for created instances."
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for Linux instances (AWS/GCP)."
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}

# AWS instances
resource "aws_key_pair" "default" {
  count      = var.platform == "aws" && var.ssh_public_key != "" ? 1 : 0
  key_name   = "server-migration"
  public_key = var.ssh_public_key
}

resource "aws_instance" "this" {
  for_each = var.platform == "aws" ? { for inst in var.instances : inst.name => inst if inst.role != "bastion" } : {}
  ami           = each.value.image
  instance_type = each.value.instance_type
  subnet_id     = each.value.subnet_id
  key_name      = var.ssh_public_key != "" ? aws_key_pair.default[0].key_name : null
  tags = merge(var.tags, {
    Name = each.key,
    Role = each.value.role
  })
}

# Azure instances
resource "azurerm_network_interface" "this" {
  for_each = var.platform == "azure" ? { for inst in var.instances : inst.name => inst } : {}
  name                = "${each.key}-nic"
  location            = lookup(var.tags, "location", "eastus")
  resource_group_name = lookup(var.tags, "resource_group", "rg-server-migration")

  ip_configuration {
    name                          = "${each.key}-ipcfg"
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "linux" {
  for_each = var.platform == "azure" ? { for inst in var.instances : inst.name => inst if inst.role != "windows" } : {}
  name                = each.key
  resource_group_name = lookup(var.tags, "resource_group", "rg-server-migration")
  location            = lookup(var.tags, "location", "eastus")
  size                = each.value.instance_type
  admin_username      = var.admin_username
  network_interface_ids = [azurerm_network_interface.this[each.key].id]
  disable_password_authentication = true
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }
  source_image_reference {
    publisher = split("/", each.value.image)[0]
    offer     = split("/", each.value.image)[1]
    sku       = split("/", each.value.image)[2]
    version   = "latest"
  }
}

resource "azurerm_windows_virtual_machine" "windows" {
  for_each = var.platform == "azure" ? { for inst in var.instances : inst.name => inst if inst.role == "windows" } : {}
  name                = each.key
  resource_group_name = lookup(var.tags, "resource_group", "rg-server-migration")
  location            = lookup(var.tags, "location", "eastus")
  size                = each.value.instance_type
  admin_username      = var.admin_username
  admin_password      = lookup(var.tags, "windows_admin_password", "ChangeM3!Pass")
  network_interface_ids = [azurerm_network_interface.this[each.key].id]
  source_image_reference {
    publisher = split("/", each.value.image)[0]
    offer     = split("/", each.value.image)[1]
    sku       = split("/", each.value.image)[2]
    version   = "latest"
  }
}

# GCP instances
resource "google_compute_instance" "this" {
  for_each = var.platform == "gcp" ? { for inst in var.instances : inst.name => inst } : {}
  name         = each.key
  machine_type = each.value.instance_type
  zone         = var.tags["zone"]

  boot_disk {
    initialize_params {
      image = each.value.image
    }
  }

  network_interface {
    subnetwork = each.value.subnet_id
  }

  metadata = {
    ssh-keys = format("%s:%s", var.admin_username, var.ssh_public_key)
  }

  labels = { for k, v in var.tags : k => replace(lower(v), " ", "-") }
}
