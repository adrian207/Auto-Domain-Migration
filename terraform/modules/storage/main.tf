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

variable "replication_bucket_name" {
  type        = string
  description = "Bucket or storage account name used for replication staging."
}

variable "tags" {
  type    = map(string)
  default = {}
}

# AWS S3 bucket for replication
resource "aws_s3_bucket" "replication" {
  count  = var.platform == "aws" ? 1 : 0
  bucket = var.replication_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "replication" {
  count  = var.platform == "aws" ? 1 : 0
  bucket = aws_s3_bucket.replication[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# Azure storage account and container
resource "azurerm_storage_account" "replication" {
  count                    = var.platform == "azure" ? 1 : 0
  name                     = substr(replace(lower(var.replication_bucket_name), "-", ""), 0, 23)
  resource_group_name      = lookup(var.tags, "resource_group", "rg-server-migration")
  location                 = lookup(var.tags, "location", "eastus")
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

resource "azurerm_storage_container" "replication" {
  count                 = var.platform == "azure" ? 1 : 0
  name                  = "replication"
  storage_account_name  = azurerm_storage_account.replication[0].name
  container_access_type = "private"
}

# GCP storage bucket
resource "google_storage_bucket" "replication" {
  count         = var.platform == "gcp" ? 1 : 0
  name          = var.replication_bucket_name
  location      = lookup(var.tags, "location", "us-central1")
  storage_class = "STANDARD"
  force_destroy = true
  labels        = { for k, v in var.tags : k => replace(lower(v), " ", "-") }
}

output "bucket_endpoint" {
  value = var.platform == "aws" ? aws_s3_bucket.replication[0].bucket_domain_name : (
    var.platform == "azure" ? azurerm_storage_account.replication[0].primary_blob_endpoint : (
    var.platform == "gcp" ? google_storage_bucket.replication[0].url : null))
}
