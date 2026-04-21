# NEG-based Load Balancer module
# Creates Global External Application Load Balancers backed by GKE Standalone NEGs.
#
# Setup flow:
# 1. Deploy K8s Service with cloud.google.com/neg annotation (Helm charts)
# 2. GKE NEG controller creates zonal NEGs automatically
# 3. Populate neg names/zones in terraform.tfvars
# 4. terraform apply creates the LB pointing to those NEGs

# Look up existing NEGs created by GKE NEG controller
locals {
  # Flatten all NEGs across all LBs for data source lookup
  all_negs = flatten([
    for lb in var.neg_load_balancers : [
      for neg in lb.backend_service.negs : {
        key  = "${neg.name}--${neg.zone}"
        name = neg.name
        zone = neg.zone
      }
    ]
  ])
}

data "google_compute_network_endpoint_group" "this" {
  for_each = { for neg in local.all_negs : neg.key => neg }

  project = var.project_id
  name    = each.value.name
  zone    = each.value.zone
}

# Static external IP for each unique global address
resource "google_compute_global_address" "this" {
  for_each = toset(distinct([
    for lb in var.neg_load_balancers :
    coalesce(lb.global_address_name, lb.name)
  ]))

  project      = var.project_id
  name         = "${each.key}-ip"
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
  labels       = var.labels
}

# Health check (HTTP or TCP)
resource "google_compute_health_check" "this" {
  for_each = { for lb in var.neg_load_balancers : lb.health_check.name => lb.health_check }

  project             = var.project_id
  name                = each.value.name
  check_interval_sec  = each.value.check_interval_sec
  timeout_sec         = each.value.timeout_sec
  healthy_threshold   = each.value.healthy_threshold
  unhealthy_threshold = each.value.unhealthy_threshold

  dynamic "http_health_check" {
    for_each = each.value.type == "HTTP" ? [1] : []
    content {
      port         = each.value.port
      request_path = each.value.request_path
    }
  }

  dynamic "tcp_health_check" {
    for_each = each.value.type == "TCP" ? [1] : []
    content {
      port = each.value.port
    }
  }
}

# Backend service with NEG backends
resource "google_compute_backend_service" "this" {
  for_each = { for lb in var.neg_load_balancers : lb.backend_service.name => lb }

  project               = var.project_id
  name                  = each.value.backend_service.name
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = each.value.backend_service.protocol
  timeout_sec           = each.value.backend_service.timeout_sec
  enable_cdn            = each.value.backend_service.enable_cdn
  health_checks         = [google_compute_health_check.this[each.value.health_check.name].id]

  session_affinity = each.value.backend_service.session_affinity
  security_policy  = each.value.backend_service.security_policy

  dynamic "log_config" {
    for_each = each.value.backend_service.enable_logging ? [1] : []
    content {
      enable      = true
      sample_rate = each.value.backend_service.log_sample_rate
    }
  }

  dynamic "backend" {
    for_each = each.value.backend_service.negs
    content {
      group                 = data.google_compute_network_endpoint_group.this["${backend.value.name}--${backend.value.zone}"].id
      balancing_mode        = each.value.backend_service.balancing_mode
      max_utilization       = each.value.backend_service.balancing_mode == "UTILIZATION" ? each.value.backend_service.max_utilization : null
      max_rate_per_endpoint = each.value.backend_service.balancing_mode == "RATE" ? each.value.backend_service.max_rate_per_endpoint : null
    }
  }
}

# URL map
resource "google_compute_url_map" "this" {
  for_each = { for lb in var.neg_load_balancers : lb.name => lb }

  project         = var.project_id
  name            = "${each.value.name}-url-map"
  default_service = google_compute_backend_service.this[each.value.backend_service.name].id

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP proxy
resource "google_compute_target_http_proxy" "this" {
  for_each = { for lb in var.neg_load_balancers : lb.name => lb }

  project = var.project_id
  name    = "${each.value.name}-http-proxy"
  url_map = google_compute_url_map.this[each.value.name].id
}

# HTTP forwarding rule
resource "google_compute_global_forwarding_rule" "http" {
  for_each = { for lb in var.neg_load_balancers : lb.name => lb }

  project               = var.project_id
  name                  = "${each.value.name}-http-rule"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_http_proxy.this[each.value.name].id
  port_range            = tostring(each.value.http_port)
  ip_address            = google_compute_global_address.this[coalesce(each.value.global_address_name, each.value.name)].address
  labels                = var.labels
}

# Google-managed SSL certificate
resource "google_compute_managed_ssl_certificate" "this" {
  for_each = {
    for lb in var.neg_load_balancers :
    lb.name => lb
    if lb.ssl_config != null && lb.ssl_config.enabled
  }

  project = var.project_id
  name    = "${each.value.name}-managed-ssl-cert"

  managed {
    domains = each.value.ssl_config.certificate_domains
  }

  lifecycle {
    create_before_destroy = true
  }
}

# HTTPS proxy (optional)
resource "google_compute_target_https_proxy" "this" {
  for_each = { for lb in var.neg_load_balancers : lb.name => lb if lb.ssl_config != null && lb.ssl_config.enabled }

  project          = var.project_id
  name             = "${each.value.name}-https-proxy"
  url_map          = google_compute_url_map.this[each.value.name].id
  ssl_certificates = [google_compute_managed_ssl_certificate.this[each.value.name].id]
}

# HTTPS forwarding rule (optional)
resource "google_compute_global_forwarding_rule" "https" {
  for_each = { for lb in var.neg_load_balancers : lb.name => lb if lb.ssl_config != null && lb.ssl_config.enabled }

  project               = var.project_id
  name                  = "${each.value.name}-https-rule"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_https_proxy.this[each.value.name].id
  port_range            = tostring(each.value.https_port)
  ip_address            = google_compute_global_address.this[coalesce(each.value.global_address_name, each.value.name)].address
  labels                = var.labels
}
