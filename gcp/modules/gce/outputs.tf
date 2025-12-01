output "instance_names" {
  description = "Map of instance names"
  value       = { for k, v in google_compute_instance.this : k => v.name }
}

output "instance_ips" {
  description = "Map of instance external IPs"
  value = {
    for k, v in google_compute_instance.this :
    k => length(v.network_interface[0].access_config) > 0 ? v.network_interface[0].access_config[0].nat_ip : null
  }
}

output "instance_group_names" {
  description = "Map of instance group names"
  value       = { for k, v in google_compute_instance_group.this : k => v.name }
}

output "instance_group_self_links" {
  description = "Map of instance group self links"
  value       = { for k, v in google_compute_instance_group.this : k => v.self_link }
}

output "instance_group_zones" {
  description = "Map of instance group zones"
  value       = { for k, v in google_compute_instance_group.this : k => v.zone }
}
