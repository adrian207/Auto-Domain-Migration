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

variable "tags" {
  type    = map(string)
  default = {}
}

variable "log_retention_days" {
  type        = number
  default     = 30
  description = "Retention period for observability artifacts."
}

# AWS CloudWatch log group
resource "aws_cloudwatch_log_group" "server_migration" {
  count             = var.platform == "aws" ? 1 : 0
  name              = "/server-migration/automation"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Azure Log Analytics workspace
resource "azurerm_log_analytics_workspace" "server_migration" {
  count               = var.platform == "azure" ? 1 : 0
  name                = "law-server-migration"
  location            = lookup(var.tags, "location", "eastus")
  resource_group_name = lookup(var.tags, "resource_group", "rg-server-migration")
  retention_in_days   = var.log_retention_days
  sku                 = "PerGB2018"
  tags                = var.tags
}

# GCP logging sink (to bucket)
resource "google_logging_project_sink" "server_migration" {
  count            = var.platform == "gcp" ? 1 : 0
  name             = "server-migration"
  destination      = "storage.googleapis.com/${lookup(var.tags, "logging_bucket", "server-migration-logs")}" 
  filter           = "resource.type=\"gce_instance\""
  unique_writer_identity = true
}
