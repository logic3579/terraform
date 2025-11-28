output "router_names" {
  description = "Map of router names"
  value       = { for k, v in google_compute_router.this : k => v.name }
}

output "router_self_links" {
  description = "Map of router self links"
  value       = { for k, v in google_compute_router.this : k => v.self_link }
}

output "nat_names" {
  description = "Map of NAT names"
  value       = { for k, v in google_compute_router_nat.this : k => v.name }
}
