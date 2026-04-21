output "cluster_ids" {
  description = "Map of cluster IDs"
  value       = { for k, v in google_container_cluster.this : k => v.id }
}

output "cluster_endpoints" {
  description = "Map of cluster endpoints"
  value       = { for k, v in google_container_cluster.this : k => v.endpoint }
  sensitive   = true
}

output "cluster_ca_certificates" {
  description = "Map of cluster CA certificates (base64 encoded)"
  value       = { for k, v in google_container_cluster.this : k => v.master_auth[0].cluster_ca_certificate }
  sensitive   = true
}

output "cluster_names" {
  description = "Map of cluster names"
  value       = { for k, v in google_container_cluster.this : k => v.name }
}

output "cluster_locations" {
  description = "Map of cluster locations"
  value       = { for k, v in google_container_cluster.this : k => v.location }
}

output "cluster_self_links" {
  description = "Map of cluster self links"
  value       = { for k, v in google_container_cluster.this : k => v.self_link }
}

output "node_pool_names" {
  description = "Map of node pool names"
  value       = { for k, v in google_container_node_pool.this : k => v.name }
}
