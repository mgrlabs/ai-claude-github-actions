# ---------------------------------------------------------------------------
# Data sources — reference existing vnet module resources
# ---------------------------------------------------------------------------

data "azurerm_virtual_network" "vnet" {
  name                = var.existing_virtual_network.vnet_name
  resource_group_name = var.existing_virtual_network.resource_group_name
}

data "azurerm_subnet" "management" {
  name                 = var.existing_virtual_network.subnet_management
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = var.existing_virtual_network.resource_group_name
}

data "azurerm_subnet" "private" {
  name                 = var.existing_virtual_network.subnet_private
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = var.existing_virtual_network.resource_group_name
}

data "azurerm_subnet" "public" {
  name                 = var.existing_virtual_network.subnet_public
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = var.existing_virtual_network.resource_group_name
}

# ---------------------------------------------------------------------------
# Firewall resource group
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "firewalls" {
  name     = var.firewall_resource_group_name
  location = var.location
}

# ---------------------------------------------------------------------------
# Active-active firewall pair
# ---------------------------------------------------------------------------

module "vmseries" {
  source   = "PaloAltoNetworks/swfw-modules/azurerm//modules/vmseries"
  version  = "~> 3.0"
  for_each = local.firewalls

  name                = each.key
  resource_group_name = azurerm_resource_group.firewalls.name
  region              = var.location

  authentication = {
    username                        = "panadmin"
    password                        = var.admin_password
    disable_password_authentication = false
  }

  image = {
    version = var.pan_os_version
    sku     = "byol"
  }

  virtual_machine = {
    size      = "Standard_D8s_v3"
    zone      = each.value.zone
    disk_name = each.value.disk_name
    disk_type = "StandardSSD_LRS"
  }

  # Interface order is significant: first = management, subsequent = dataplane
  interfaces = [
    {
      name      = "${each.key}-mgmt"
      subnet_id = data.azurerm_subnet.management.id
      ip_configurations = {
        primary = {
          name             = "primary"
          primary          = true
          create_public_ip = true
          public_ip_name   = each.value.mgmt_pip
        }
      }
    },
    {
      name      = "${each.key}-private"
      subnet_id = data.azurerm_subnet.private.id
      ip_configurations = {
        primary = {
          name    = "primary"
          primary = true
        }
      }
    },
    {
      name      = "${each.key}-public"
      subnet_id = data.azurerm_subnet.public.id
      ip_configurations = {
        primary = {
          name    = "primary"
          primary = true
        }
      }
    }
  ]
}
