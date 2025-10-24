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
  description = "Target platform (aws|azure|gcp)."
  type        = string
}

variable "cidr_block" {
  description = "Primary network CIDR."
  type        = string
}

variable "subnet_cidrs" {
  description = "Map of subnet names to CIDR blocks."
  type        = map(string)
}

variable "tags" {
  description = "Common tags or labels."
  type        = map(string)
  default     = {}
}

# AWS networking
resource "aws_vpc" "this" {
  count             = var.platform == "aws" ? 1 : 0
  cidr_block        = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(var.tags, {
    Name = "server-migration-vpc"
  })
}

resource "aws_subnet" "this" {
  for_each = var.platform == "aws" ? var.subnet_cidrs : {}
  vpc_id   = aws_vpc.this[0].id
  cidr_block = each.value
  tags = merge(var.tags, {
    Name = "server-migration-${each.key}"
  })
}

# Azure networking
resource "azurerm_resource_group" "this" {
  count    = var.platform == "azure" ? 1 : 0
  name     = "rg-server-migration"
  location = lookup(var.tags, "location", "eastus")
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  count               = var.platform == "azure" ? 1 : 0
  name                = "vnet-server-migration"
  address_space       = [var.cidr_block]
  location            = azurerm_resource_group.this[0].location
  resource_group_name = azurerm_resource_group.this[0].name
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.platform == "azure" ? var.subnet_cidrs : {}
  name                 = "subnet-${each.key}"
  resource_group_name  = azurerm_resource_group.this[0].name
  virtual_network_name = azurerm_virtual_network.this[0].name
  address_prefixes     = [each.value]
}

# GCP networking
resource "google_compute_network" "this" {
  count                   = var.platform == "gcp" ? 1 : 0
  name                    = "server-migration-net"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "this" {
  for_each      = var.platform == "gcp" ? var.subnet_cidrs : {}
  name          = "subnet-${each.key}"
  ip_cidr_range = each.value
  region        = "us-central1"
  network       = google_compute_network.this[0].name
}

output "vpc_id" {
  value = var.platform == "aws" ? aws_vpc.this[0].id : null
}

output "resource_group" {
  value = var.platform == "azure" ? azurerm_resource_group.this[0].name : null
}

output "network_name" {
  value = var.platform == "gcp" ? google_compute_network.this[0].name : null
}

output "subnet_ids" {
  value = var.platform == "aws" ? { for k, v in aws_subnet.this : k => v.id } : (
    var.platform == "azure" ? { for k, v in azurerm_subnet.this : k => v.id } : (
    var.platform == "gcp" ? { for k, v in google_compute_subnetwork.this : k => v.id } : {}))
}
