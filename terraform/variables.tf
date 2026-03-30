variable "existing_virtual_network" {
  description = "Names of the existing VNet and subnets to attach the firewalls to"
  type = object({
    resource_group_name    = string
    vnet_name              = string
    subnet_management      = string
    subnet_private         = string
    subnet_public          = string
  })
  default = {
    resource_group_name    = "rg-palo-implementation"
    vnet_name              = "vnet-palo-implementation"
    subnet_management      = "sn-firewall-management"
    subnet_private         = "sn-private"
    subnet_public          = "sn-public"
  }
}

variable "location" {
  description = "Azure region to deploy all resources into"
  type        = string
  default     = "australiaeast"
}

variable "firewall_resource_group_name" {
  description = "Name of the resource group to create and deploy the firewall VMs into"
  type        = string
  default     = "rmit-paloalto-rg"
}

variable "admin_password" {
  description = "Admin password for the Palo Alto VM-Series firewalls (panadmin user)"
  type        = string
  sensitive   = true
}

variable "pan_os_version" {
  description = "PAN-OS version to deploy"
  type        = string
  default     = "11.1.607"
}
