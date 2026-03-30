# Active-active firewall pair
# Each firewall is placed in a separate Availability Zone for redundancy.

locals {
  firewalls = {
    "fw-palo-01" = {
      zone      = "1"
      disk_name = "disk-fw-palo-01"
      mgmt_pip  = "pip-fw-palo-01-mgmt"
    }
    "fw-palo-02" = {
      zone      = "2"
      disk_name = "disk-fw-palo-02"
      mgmt_pip  = "pip-fw-palo-02-mgmt"
    }
  }
}
