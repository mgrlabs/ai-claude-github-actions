terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# NOTE: This module requires azurerm ~> 4.0. If the vnet module is applied
# from a separate state, update its provider version to ~> 4.0 as well before
# running this module.
# Provider configuration is intentionally absent — callers must pass the
# azurerm provider so that depends_on, count, and for_each remain available.
