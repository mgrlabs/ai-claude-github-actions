# ---------------------------------------------------------------------------
# Test harness — creates all infrastructure dependencies and instantiates
# the parent module. Intended for integration/smoke testing only;
# do not use in production.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "location" {
  description = "Azure region to deploy all resources into"
  type        = string
  default     = "australiaeast"
}

variable "pan_os_version" {
  description = "PAN-OS version to deploy"
  type        = string
  default     = "11.1.607"
}

# ---------------------------------------------------------------------------
# Generated admin password
# ---------------------------------------------------------------------------

resource "random_password" "admin" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

# ---------------------------------------------------------------------------
# Resource group
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "rg" {
  name     = "palo-testharness-rg"
  location = var.location
}

# ---------------------------------------------------------------------------
# Virtual network and subnets
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "vnet" {
  name                = "rmit-palo-test-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "management" {
  name                 = "sn-firewalls-management"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "private" {
  name                 = "sn-firewalls-private"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "public" {
  name                 = "sn-firewalls-public"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# ---------------------------------------------------------------------------
# NAT Gateway — provides outbound internet access for management traffic
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "nat_pip" {
  name                = "pip-nat-gateway"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "nat" {
  name                = "natgw-palo-implementation"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "nat_pip" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat_pip.id
}

resource "azurerm_subnet_nat_gateway_association" "management" {
  subnet_id      = azurerm_subnet.management.id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}

# ---------------------------------------------------------------------------
# Module under test
# depends_on ensures all data sources resolve after resources are created
# ---------------------------------------------------------------------------

module "firewalls" {
  source = "../"

  location       = var.location
  admin_password = random_password.admin.result
  pan_os_version = var.pan_os_version

  existing_virtual_network = {
    resource_group_name = azurerm_resource_group.rg.name
    vnet_name           = azurerm_virtual_network.vnet.name
    subnet_management   = azurerm_subnet.management.name
    subnet_private      = azurerm_subnet.private.name
    subnet_public       = azurerm_subnet.public.name
  }

  depends_on = [
    azurerm_subnet.management,
    azurerm_subnet.private,
    azurerm_subnet.public,
    azurerm_subnet_nat_gateway_association.management,
  ]
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "firewall_management_ips" {
  description = "Public management IP addresses for each firewall"
  value       = module.firewalls.firewall_management_ips
}

output "nat_gateway_ip" {
  description = "Public IP address of the NAT Gateway"
  value       = azurerm_public_ip.nat_pip.ip_address
}

output "admin_password" {
  description = "Generated admin password for the panadmin user"
  value       = random_password.admin.result
  sensitive   = true
}
