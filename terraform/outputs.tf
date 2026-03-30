output "firewall_management_ips" {
  description = "Public management IP addresses for each firewall"
  value = {
    for k, v in module.vmseries : k => v.mgmt_ip_address
  }
}

output "firewall_interfaces" {
  description = "All network interfaces for each firewall"
  value = {
    for k, v in module.vmseries : k => v.interfaces
  }
}
