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
  name     = "${var.client_prefix}-${var.resource_group_name_firewalls}"
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
    username                        = var.admin_username
    password                        = var.admin_password
    disable_password_authentication = false
  }

  image = {
    version = var.pan_os_version
    sku     = "byol"
  }

  virtual_machine = {
    size      = "Standard_D8s_v3" # Temp size for testing; adjust as needed for production
    zone      = each.value.zone
    disk_name = "${each.key}-osdisk"
    disk_type = "StandardSSD_LRS"
  }

  # Interface order is significant: first = management, subsequent = dataplane
  interfaces = [
    {
      # eth0 = management
      name      = "${each.key}-mgmt"
      subnet_id = data.azurerm_subnet.management.id
      ip_configurations = {
        primary = {
          name             = "primary"
          primary          = true
          create_public_ip = false
        }
      }
    },
    {
      # eth1/1 = public (untrusted)
      name      = "${each.key}-public"
      subnet_id = data.azurerm_subnet.public.id
      ip_configurations = {
        primary = {
          name    = "primary"
          primary = true
        }
      }
    },
    {
      # eth1/2 = private (trusted)
      name      = "${each.key}-private"
      subnet_id = data.azurerm_subnet.private.id
      ip_configurations = {
        primary = {
          name    = "primary"
          primary = true
        }
      }
    }
  ]
}

# ---------------------------------------------------------------------------
# Internal Load Balancer — Private (trusted) side
# ---------------------------------------------------------------------------

resource "azurerm_lb" "private" {
  name                = "${var.client_prefix}-lb-private"
  location            = var.location
  resource_group_name = azurerm_resource_group.firewalls.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "fe-private"
    subnet_id                     = data.azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "private" {
  name            = "bp-private"
  loadbalancer_id = azurerm_lb.private.id
}

resource "azurerm_lb_probe" "private" {
  name            = "probe-private"
  loadbalancer_id = azurerm_lb.private.id
  protocol        = "Tcp"
  port            = 443
}

resource "azurerm_lb_rule" "private" {
  name                           = "ha-ports-private"
  loadbalancer_id                = azurerm_lb.private.id
  frontend_ip_configuration_name = "fe-private"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.private.id]
  probe_id                       = azurerm_lb_probe.private.id
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  floating_ip_enabled            = true
}

resource "azurerm_network_interface_backend_address_pool_association" "private" {
  for_each = local.firewalls

  network_interface_id    = module.vmseries[each.key].interfaces["${each.key}-private"].id
  ip_configuration_name   = "primary"
  backend_address_pool_id = azurerm_lb_backend_address_pool.private.id
}

# ---------------------------------------------------------------------------
# Internal Load Balancer — Public (untrusted) side
# ---------------------------------------------------------------------------

resource "azurerm_lb" "public" {
  name                = "${var.client_prefix}-lb-public"
  location            = var.location
  resource_group_name = azurerm_resource_group.firewalls.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "fe-public"
    subnet_id                     = data.azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "public" {
  name            = "bp-public"
  loadbalancer_id = azurerm_lb.public.id
}

resource "azurerm_lb_probe" "public" {
  name            = "probe-public"
  loadbalancer_id = azurerm_lb.public.id
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_rule" "public" {
  name                           = "ha-ports-public"
  loadbalancer_id                = azurerm_lb.public.id
  frontend_ip_configuration_name = "fe-public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.public.id]
  probe_id                       = azurerm_lb_probe.public.id
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  floating_ip_enabled            = true
}

resource "azurerm_network_interface_backend_address_pool_association" "public" {
  for_each = local.firewalls

  network_interface_id    = module.vmseries[each.key].interfaces["${each.key}-public"].id
  ip_configuration_name   = "primary"
  backend_address_pool_id = azurerm_lb_backend_address_pool.public.id
}
