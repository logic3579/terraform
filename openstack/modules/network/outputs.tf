output "networks" {
  description = "Networks keyed by name"
  value = {
    for k, v in openstack_networking_network_v2.this : k => {
      id   = v.id
      mtu  = v.mtu
      name = v.name
    }
  }
}

output "subnets" {
  description = "Subnets keyed by network-name/subnet-name"
  value = {
    for k, v in openstack_networking_subnet_v2.this : k => {
      id         = v.id
      cidr       = v.cidr
      network_id = v.network_id
    }
  }
}

output "routers" {
  description = "Routers keyed by name"
  value = {
    for k, v in openstack_networking_router_v2.this : k => {
      id = v.id
    }
  }
}

output "security_groups" {
  description = "Security groups keyed by name"
  value = {
    for k, v in openstack_networking_secgroup_v2.this : k => {
      id   = v.id
      name = v.name
    }
  }
}

output "floating_ips" {
  description = "Floating IPs keyed by name"
  value = {
    for k, v in openstack_networking_floatingip_v2.this : k => {
      id      = v.id
      address = v.address
    }
  }
}

# Cross-module references — used by compute module to resolve names → IDs
output "network_id_by_name" {
  description = "Map of network name → id"
  value       = { for k, v in openstack_networking_network_v2.this : k => v.id }
}

output "secgroup_id_by_name" {
  description = "Map of security group name → id"
  value       = { for k, v in openstack_networking_secgroup_v2.this : k => v.id }
}
