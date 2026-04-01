# Active-active firewall pair
# Each firewall is placed in a separate Availability Zone for redundancy.

locals {
  firewalls = {
    "fw-palo-01" = {
      zone      = "1"
    }
    "fw-palo-02" = {
      zone      = "2"
    }
  }
}
