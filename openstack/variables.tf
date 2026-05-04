variable "networks" {
  description = "Tenant networks with their subnets"
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
  description = "Neutron routers + interfaces"
  type = list(object({
    name                  = string
    admin_state_up        = optional(bool, true)
    distributed           = optional(bool)
    external_network_name = optional(string) # data-source lookup of an existing external network
    enable_snat           = optional(bool)

    # subnets attached as router interfaces
    interfaces = optional(list(object({
      network_name = string
      subnet_name  = string
    })), [])
  }))
  default = []
}

variable "security_groups" {
  description = "Security groups and their rules"
  type = list(object({
    name        = string
    description = optional(string)

    rules = optional(list(object({
      direction        = string # ingress | egress
      ethertype        = optional(string, "IPv4")
      protocol         = optional(string) # tcp | udp | icmp | ...
      port_range_min   = optional(number)
      port_range_max   = optional(number)
      remote_ip_prefix = optional(string) # CIDR
      remote_group     = optional(string) # name of another SG in this list
      description      = optional(string)
    })), [])
  }))
  default = []

  validation {
    condition = alltrue(flatten([
      for sg in var.security_groups : [
        for r in coalesce(sg.rules, []) : contains(["ingress", "egress"], r.direction)
      ]
    ]))
    error_message = "Security group rule direction must be 'ingress' or 'egress'."
  }
}

variable "floating_ips" {
  description = "Floating IPs (allocated from an external network pool)"
  type = list(object({
    name = string
    pool = string # name of the external network
  }))
  default = []
}

variable "keypairs" {
  description = "Compute keypairs"
  type = list(object({
    name       = string
    public_key = string
  }))
  default = []
}

variable "instances" {
  description = "Compute instances"
  type = list(object({
    name              = string
    image_name        = optional(string) # required unless boot_volume_name is set
    flavor_name       = string
    keypair_name      = optional(string)
    user_data         = optional(string)
    metadata          = optional(map(string), {})
    availability_zone = optional(string)
    security_groups   = optional(list(string), []) # SG names

    networks = list(object({
      network_name = string
      fixed_ip_v4  = optional(string)
    }))

    boot_volume_name = optional(string) # boot from an existing var.volumes entry
  }))
  default = []
}

variable "volumes" {
  description = "Cinder block volumes"
  type = list(object({
    name              = string
    description       = optional(string)
    size              = number # GiB
    volume_type       = optional(string)
    availability_zone = optional(string)
    image_name        = optional(string) # source Glance image (data lookup)
    metadata          = optional(map(string), {})
  }))
  default = []
}
