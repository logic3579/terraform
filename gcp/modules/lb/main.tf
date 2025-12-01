# Static external IP for each unique global address
# Multiple load balancers can share the same IP by using the same global_address_name
resource "google_compute_global_address" "this" {
  for_each = toset(distinct([
    for lb in var.load_balancers :
    coalesce(lb.global_address_name, lb.name)
  ]))

  project      = var.project_id
  name         = "${each.key}-ip"
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
}

# Health check (TCP)
resource "google_compute_health_check" "this" {
  for_each = { for lb in var.load_balancers : lb.health_check.name => lb.health_check }

  project             = var.project_id
  name                = each.value.name
  check_interval_sec  = each.value.check_interval_sec
  timeout_sec         = each.value.timeout_sec
  healthy_threshold   = each.value.healthy_threshold
  unhealthy_threshold = each.value.unhealthy_threshold

  tcp_health_check {
    port = each.value.port
  }
}

# Backend service
resource "google_compute_backend_service" "this" {
  for_each = { for lb in var.load_balancers : lb.backend_service.name => lb }

  project               = var.project_id
  name                  = each.value.backend_service.name
  load_balancing_scheme = "EXTERNAL_MANAGED" # Use new Application Load Balancer (not Classic)
  protocol              = each.value.backend_service.protocol
  port_name             = each.value.backend_service.port_name
  timeout_sec           = each.value.backend_service.timeout_sec
  enable_cdn            = each.value.backend_service.enable_cdn
  health_checks         = [google_compute_health_check.this[each.value.health_check.name].id]

  session_affinity = each.value.backend_service.session_affinity

  # Security policy (Cloud Armor)
  security_policy = each.value.backend_service.security_policy

  # Log configuration
  dynamic "log_config" {
    for_each = each.value.backend_service.enable_logging ? [1] : []
    content {
      enable      = true
      sample_rate = each.value.backend_service.log_sample_rate
    }
  }

  dynamic "backend" {
    for_each = each.value.backend_service.instance_groups
    content {
      group                 = backend.value
      balancing_mode        = each.value.backend_service.balancing_mode
      max_utilization       = each.value.backend_service.balancing_mode == "UTILIZATION" ? each.value.backend_service.max_utilization : null
      max_rate_per_instance = each.value.backend_service.balancing_mode == "RATE" ? each.value.backend_service.max_rate_per_instance : null
    }
  }
}

# URL map
resource "google_compute_url_map" "this" {
  for_each = { for lb in var.load_balancers : lb.name => lb }

  project         = var.project_id
  name            = "${each.value.name}-url-map"
  default_service = google_compute_backend_service.this[each.value.backend_service.name].id

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP proxy
resource "google_compute_target_http_proxy" "this" {
  for_each = { for lb in var.load_balancers : lb.name => lb }

  project = var.project_id
  name    = "${each.value.name}-http-proxy"
  url_map = google_compute_url_map.this[each.key].id
}

# HTTP forwarding rule
resource "google_compute_global_forwarding_rule" "http" {
  for_each = { for lb in var.load_balancers : lb.name => lb }

  project               = var.project_id
  name                  = "${each.value.name}-http-rule"
  load_balancing_scheme = "EXTERNAL_MANAGED" # Use new Application Load Balancer (not Classic)
  target                = google_compute_target_http_proxy.this[each.key].id
  port_range            = tostring(each.value.http_port)
  ip_address            = google_compute_global_address.this[coalesce(each.value.global_address_name, each.key)].address
}

# Self-managed SSL certificate (when private_key and certificate are provided)
resource "google_compute_ssl_certificate" "this" {
  for_each = {
    for lb in var.load_balancers :
    lb.name => lb
    if lb.ssl_config != null && lb.ssl_config.enabled && lb.ssl_config.private_key != null && lb.ssl_config.certificate != null
  }

  project     = var.project_id
  name        = "${each.key}-ssl-cert"
  private_key = each.value.ssl_config.private_key
  certificate = each.value.ssl_config.certificate

  lifecycle {
    create_before_destroy = true
  }
}

# Google-managed SSL certificate (when only certificate_domains are provided)
resource "google_compute_managed_ssl_certificate" "this" {
  for_each = {
    for lb in var.load_balancers :
    lb.name => lb
    if lb.ssl_config != null && lb.ssl_config.enabled && lb.ssl_config.private_key == null && lb.ssl_config.certificate == null
  }

  project = var.project_id
  name    = "${each.key}-managed-ssl-cert"

  managed {
    domains = each.value.ssl_config.certificate_domains
  }

  lifecycle {
    create_before_destroy = true
  }
}

# HTTPS proxy (optional)
resource "google_compute_target_https_proxy" "this" {
  for_each = { for lb in var.load_balancers : lb.name => lb if lb.ssl_config != null && lb.ssl_config.enabled }

  project = var.project_id
  name    = "${each.key}-https-proxy"
  url_map = google_compute_url_map.this[each.key].id

  # Use self-managed certificate if available, otherwise use Google-managed certificate
  ssl_certificates = [
    try(google_compute_ssl_certificate.this[each.key].id, google_compute_managed_ssl_certificate.this[each.key].id)
  ]
}

# HTTPS forwarding rule (optional)
resource "google_compute_global_forwarding_rule" "https" {
  for_each = { for lb in var.load_balancers : lb.name => lb if lb.ssl_config != null && lb.ssl_config.enabled }

  project               = var.project_id
  name                  = "${each.key}-https-rule"
  load_balancing_scheme = "EXTERNAL_MANAGED" # Use new Application Load Balancer (not Classic)
  target                = google_compute_target_https_proxy.this[each.key].id
  port_range            = tostring(each.value.https_port)
  ip_address            = google_compute_global_address.this[coalesce(each.value.global_address_name, each.key)].address
}
