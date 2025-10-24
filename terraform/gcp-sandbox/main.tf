terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

locals {
  tags = merge(var.tags, {
    location       = var.region,
    zone           = var.zone,
    logging_bucket = var.logging_bucket
  })
}

module "network" {
  source       = "../modules/network"
  platform     = "gcp"
  cidr_block   = var.vpc_cidr
  subnet_cidrs = var.subnet_cidrs
  tags         = locals.tags
}

module "storage" {
  source                  = "../modules/storage"
  platform                = "gcp"
  replication_bucket_name = var.replication_bucket
  tags                    = locals.tags
}

module "observability" {
  source             = "../modules/observability"
  platform           = "gcp"
  log_retention_days = var.log_retention_days
  tags               = locals.tags
}

module "compute" {
  source         = "../modules/compute"
  platform       = "gcp"
  admin_username = var.admin_username
  ssh_public_key = var.ssh_public_key
  instances = [
    for server in var.servers : {
      name          = server.name
      role          = server.role
      instance_type = server.machine_type
      image         = server.image
      subnet_id     = module.network.subnet_ids[server.subnet]
    }
  ]
  tags = locals.tags
}
