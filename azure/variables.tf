/* General 
====================================================*/

variable "client_prefix" {
  type        = string
  description = "Prefix to use for all resources created by this module. This is used to create unique resource names."
  default     = "mglb"
}

variable "resource_group_name_firewalls" {
  type        = string
  description = "Resource group name of where Hub Network resources will be deployed."
  default     = "ae-firewalls-rg"
}

variable "tags" {
  type        = map(string)
  description = "Optional. Resource tags."
  default     = {}
}

variable "resource_lock_level" {
  type        = string
  description = "Optional. Specify the type of resource lock. Allowed values: 'CanNotDelete', 'ReadOnly' or 'None'."
  default     = "None"
}

variable "existing_virtual_network" {
  description = "Required. Virtual network block of existing virtual network to deploy the firewall into."
  type = object({
    resource_group_name    = string
    vnet_name              = string
    subnet_management      = string
    subnet_private         = string
    subnet_public          = string
    subnet_ha              = string
  })
  default = {
    resource_group_name    = "mgrl-ae-network-rg"
    vnet_name              = "mgrl-ae-inspection-vnet"
    subnet_management      = "sn-firewall-management"
    subnet_private         = "sn-firewall-private"
    subnet_public          = "sn-firewall-public"
    subnet_ha              = "sn-firewall-ha"
  }
}

variable "location" {
  description = "Azure region to deploy all resources into"
  type        = string
  default     = "australiaeast"
}

variable "admin_username" {
  description = "Admin username for the Palo Alto VM-Series firewalls"
  type        = string
  default     = "panadmin"
}

variable "admin_password" {
  description = "Admin password for the Palo Alto VM-Series firewalls (panadmin user)"
  type        = string
  sensitive   = true
}

variable "pan_os_version" {
  description = "PAN-OS version to deploy"
  type        = string
  default     = "12.1.5"
}
