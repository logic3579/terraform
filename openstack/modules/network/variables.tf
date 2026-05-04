variable "networks" {
  type = list(object({
    name           = string
    description    = optional(string)
    admin_state_up = optional(bool, true)
    shared         = optional(bool, false)
    external       = optional(bool, false)
    mtu            = optional(number)
    tags           = optional(list(string), [])
    subnets = optional(list(object({
      name            = string
      cidr            = string
      ip_version      = optional(number, 4)
      gateway_ip      = optional(string)
      no_gateway      = optional(bool, false)
      enable_dhcp     = optional(bool, true)
      dns_nameservers = optional(list(string), [])
      allocation_pools = optional(list(object({
        start = string
        end   = string
      })), [])
    })), [])
  }))
  default = []
}

variable "routers" {
  type = list(object({
    name                  = string
    admin_state_up        = optional(bool, true)
    distributed           = optional(bool)
    external_network_name = optional(string)
    enable_snat           = optional(bool)
    interfaces = optional(list(object({
      network_name = string
      subnet_name  = string
    })), [])
  }))
  default = []
}

variable "security_groups" {
  type = list(object({
    name        = string
    description = optional(string)
    rules = optional(list(object({
      direction        = string
      ethertype        = optional(string, "IPv4")
      protocol         = optional(string)
      port_range_min   = optional(number)
      port_range_max   = optional(number)
      remote_ip_prefix = optional(string)
      remote_group     = optional(string)
      description      = optional(string)
    })), [])
  }))
  default = []
}

variable "floating_ips" {
  type = list(object({
    name = string
    pool = string
  }))
  default = []
}
