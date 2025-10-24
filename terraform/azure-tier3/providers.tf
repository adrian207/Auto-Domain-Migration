# Terraform Provider Configuration for Tier 3 (Enterprise)
# Purpose: AKS-based migration platform with full HA

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Backend configuration for state management
  backend "azurerm" {
    # Configure these values or pass via -backend-config
    # resource_group_name  = "terraform-state-rg"
    # storage_account_name = "tfstatemigration"
    # container_name       = "tfstate"
    # key                  = "tier3.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }

    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }

    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }
  }
}

# Note: Kubernetes, Helm, and Kubectl providers are configured after AKS deployment
# To use these providers, run: terraform init -upgrade after AKS cluster is created
# Then configure providers manually or use separate Terraform workspace

