terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  base_tags = merge(var.tags, {
    location                = var.location,
    resource_group          = module.network.resource_group,
    windows_admin_password  = var.windows_admin_password
  })
}

module "network" {
  source       = "../modules/network"
  platform     = "azure"
  cidr_block   = var.vnet_cidr
  subnet_cidrs = var.subnet_cidrs
  tags         = merge(var.tags, { location = var.location })
}

module "storage" {
  source                  = "../modules/storage"
  platform                = "azure"
  replication_bucket_name = var.storage_account_name
  tags = merge(local.base_tags, {
    resource_group = module.network.resource_group
  })
}

module "observability" {
  source             = "../modules/observability"
  platform           = "azure"
  log_retention_days = var.log_retention_days
  tags               = local.base_tags
}

module "compute" {
  source         = "../modules/compute"
  platform       = "azure"
  admin_username = var.admin_username
  ssh_public_key = var.ssh_public_key
  instances = [
    for server in var.servers : {
      name          = server.name
      role          = server.role
      instance_type = server.size
      image         = server.image
      subnet_id     = module.network.subnet_ids[server.subnet]
    }
  ]
  tags = local.base_tags
}
