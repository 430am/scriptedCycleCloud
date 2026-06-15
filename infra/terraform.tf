terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.20"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # Remote state. Uncomment and fill in once a backend storage account exists.
  # Migrate from local state with:  terraform init -migrate-state
  #
  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate"
  #   storage_account_name = "<unique-name>"
  #   container_name       = "tfstate"
  #   key                  = "cyclecloud.tfstate"
  #   use_azuread_auth     = true
  # }
}

provider "azurerm" {
  storage_use_azuread = true

  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  # subscription_id is read from ARM_SUBSCRIPTION_ID; do not hardcode.
}

provider "azuread" {}
