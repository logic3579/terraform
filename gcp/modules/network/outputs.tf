output "networks" {
  description = "Map of VPC networks"
  value = {
    for k, v in google_compute_network.this : k => {
      name      = v.name
      self_link = v.self_link
      id        = v.id
    }
  }
}

output "subnets" {
  description = "Map of subnets with network reference"
  value = {
    for k, v in google_compute_subnetwork.this : k => {
      name          = v.name
      network       = v.network
      self_link     = v.self_link
      ip_cidr_range = v.ip_cidr_range
      region        = v.region
    }
  }
}

output "firewalls" {
  description = "Map of firewall rules"
  value = {
    for k, v in google_compute_firewall.this : k => {
      name      = v.name
      network   = v.network
      self_link = v.self_link
    }
  }
}
