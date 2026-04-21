output "neg_lb_ip_addresses" {
  description = "Map of NEG load balancer IP addresses"
  value       = { for k, v in google_compute_global_address.this : k => v.address }
}

output "neg_lb_urls" {
  description = "Map of NEG load balancer URLs"
  value = {
    for lb in var.neg_load_balancers :
    lb.name => {
      http  = "http://${google_compute_global_address.this[coalesce(lb.global_address_name, lb.name)].address}:${lb.http_port}"
      https = lb.ssl_config != null && lb.ssl_config.enabled ? "https://${google_compute_global_address.this[coalesce(lb.global_address_name, lb.name)].address}:${lb.https_port}" : null
    }
  }
}

output "neg_backend_service_names" {
  description = "Map of NEG backend service names"
  value       = { for k, v in google_compute_backend_service.this : k => v.name }
}

output "neg_health_check_names" {
  description = "Map of NEG health check names"
  value       = { for k, v in google_compute_health_check.this : k => v.name }
}
