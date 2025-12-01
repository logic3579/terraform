output "lb_ip_addresses" {
  description = "Map of load balancer IP addresses"
  value       = { for k, v in google_compute_global_address.this : k => v.address }
}

output "lb_urls" {
  description = "Map of load balancer URLs"
  value = {
    for k, v in var.load_balancers :
    k => {
      http  = "http://${google_compute_global_address.this[coalesce(v.global_address_name, k)].address}:${v.http_port}"
      https = v.ssl_config != null && v.ssl_config.enabled ? "https://${google_compute_global_address.this[coalesce(v.global_address_name, k)].address}:${v.https_port}" : null
    }
  }
}

output "backend_service_names" {
  description = "Map of backend service names"
  value       = { for k, v in google_compute_backend_service.this : k => v.name }
}

output "health_check_names" {
  description = "Map of health check names"
  value       = { for k, v in google_compute_health_check.this : k => v.name }
}
