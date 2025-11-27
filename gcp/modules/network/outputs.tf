output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.this.name
}

output "network_self_link" {
  description = "Self link of the VPC network"
  value       = google_compute_network.this.self_link
}

output "subnets" {
  description = "List of created subnets with basic info"
  value = [
    for s in google_compute_subnetwork.this : {
      name          = s.name
      self_link     = s.self_link
      ip_cidr_range = s.ip_cidr_range
      region        = s.region
    }
  ]
}
