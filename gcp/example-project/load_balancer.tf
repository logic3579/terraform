# GCP Global External Application Load Balancer Configuration

# 1. 创建静态外部 IP 地址（用于 Load Balancer）
resource "google_compute_global_address" "lb_external_ip" {
  name         = var.lb_external_ip_name
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
}

# 2. 创建 Health Check（探测 TCP 80 端口）
resource "google_compute_health_check" "backend_health_check" {
  name                = var.lb_health_check_name
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  tcp_health_check {
    port = 80
  }
}

# 3. 创建 Backend Service
resource "google_compute_backend_service" "global_backend" {
  name                  = var.lb_backend_service_name
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  enable_cdn            = false
  health_checks         = [google_compute_health_check.backend_health_check.id]
  load_balancing_scheme = "EXTERNAL_MANAGED"

  # Session affinity 配置
  session_affinity = "CLIENT_IP"

  # Locality LB policy - 使用 RING_HASH 以支持 consistent_hash
  locality_lb_policy = "RING_HASH"

  # Consistent hash 配置
  consistent_hash {
    minimum_ring_size = 1024
  }

  # 动态添加 Backend（Instance Groups）
  dynamic "backend" {
    for_each = var.lb_backends
    content {
      group                 = google_compute_instance_group.instance_groups[backend.value.instance_group_key].self_link
      balancing_mode        = backend.value.balancing_mode
      capacity_scaler       = backend.value.capacity_scaler
      max_utilization       = backend.value.balancing_mode == "UTILIZATION" ? backend.value.max_utilization : null
      max_rate_per_instance = backend.value.balancing_mode == "RATE" ? backend.value.max_rate_per_instance : null
    }
  }

  # 关闭 Cloud Armor
  # security_policy 不设置即为关闭

  # 关闭 Logging
  log_config {
    enable      = false
    sample_rate = 0.0
  }
}

# 4. 创建 URL Map（Routing Rules - Simple host and path rule）
resource "google_compute_url_map" "lb_url_map" {
  name            = var.lb_name
  default_service = google_compute_backend_service.global_backend.id

  # 使用默认的 Simple host and path rule
  # 所有流量都路由到 default_service

  # 生命周期管理：先创建新资源再删除旧资源
  lifecycle {
    create_before_destroy = true
  }
}

# 5. 创建 HTTP Target Proxy
resource "google_compute_target_http_proxy" "lb_http_proxy" {
  name    = "${var.lb_name}-http-proxy"
  url_map = google_compute_url_map.lb_url_map.id
}

# 6. 创建 Global Forwarding Rule（Frontend Configuration）
resource "google_compute_global_forwarding_rule" "lb_forwarding_rule" {
  name                  = var.lb_forwarding_rule_name
  target                = google_compute_target_http_proxy.lb_http_proxy.id
  port_range            = "80"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb_external_ip.address

  # 注意：ip_version 不能与 ip_address 同时指定
  # IP 版本会从 ip_address 自动推断（IPv4）
}

# ========================================
# 8000 端口服务配置（revo-ai）
# ========================================

# 7. 创建 Health Check for 8000 端口
resource "google_compute_health_check" "backend_health_check_8000" {
  name                = "${var.lb_health_check_name}-8000"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  tcp_health_check {
    port = 8000
  }
}

# 8. 创建 Backend Service for 8000 端口
resource "google_compute_backend_service" "global_backend_8000" {
  name                  = "${var.lb_backend_service_name}-8000"
  protocol              = "HTTP"
  port_name             = "revo-ai" # 使用 revo-ai 命名端口
  timeout_sec           = 30
  enable_cdn            = false
  health_checks         = [google_compute_health_check.backend_health_check_8000.id]
  load_balancing_scheme = "EXTERNAL_MANAGED"

  # Session affinity 配置
  session_affinity = "CLIENT_IP"

  # Locality LB policy - 使用 RING_HASH 以支持 consistent_hash
  locality_lb_policy = "RING_HASH"

  # Consistent hash 配置
  consistent_hash {
    minimum_ring_size = 1024
  }

  # 动态添加 Backend（Instance Groups）
  dynamic "backend" {
    for_each = var.lb_backends
    content {
      group                 = google_compute_instance_group.instance_groups[backend.value.instance_group_key].self_link
      balancing_mode        = backend.value.balancing_mode
      capacity_scaler       = backend.value.capacity_scaler
      max_utilization       = backend.value.balancing_mode == "UTILIZATION" ? backend.value.max_utilization : null
      max_rate_per_instance = backend.value.balancing_mode == "RATE" ? backend.value.max_rate_per_instance : null
    }
  }

  # 关闭 Logging
  log_config {
    enable      = false
    sample_rate = 0.0
  }
}

# 9. 创建 URL Map for 8000 端口
resource "google_compute_url_map" "lb_url_map_8000" {
  name            = "${var.lb_name}-8000"
  default_service = google_compute_backend_service.global_backend_8000.id

  # 使用默认的 Simple host and path rule
  # 所有流量都路由到 8000 端口的 backend service

  # 生命周期管理：先创建新资源再删除旧资源
  lifecycle {
    create_before_destroy = true
  }
}

# 10. 创建 HTTP Target Proxy for 8000 端口
resource "google_compute_target_http_proxy" "lb_http_proxy_8000" {
  name    = "${var.lb_name}-http-proxy-8000"
  url_map = google_compute_url_map.lb_url_map_8000.id
}

# 11. 创建 Global Forwarding Rule for 8000 端口
resource "google_compute_global_forwarding_rule" "lb_forwarding_rule_8000" {
  name                  = "${var.lb_forwarding_rule_name}-8000"
  target                = google_compute_target_http_proxy.lb_http_proxy_8000.id
  port_range            = "8000"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb_external_ip.address

  # 注意：ip_version 不能与 ip_address 同时指定
  # IP 版本会从 ip_address 自动推断（IPv4）
}

# HTTPS 证书资源
resource "google_compute_managed_ssl_certificate" "lb_managed_cert" {
  name = var.lb_ssl_certificate_name
  managed {
    domains = var.lb_ssl_certificate_domains
  }
}

# HTTPS Target Proxy
resource "google_compute_target_https_proxy" "lb_https_proxy" {
  name             = "${var.lb_name}-https-proxy"
  url_map          = google_compute_url_map.lb_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.lb_managed_cert.id]
}

# HTTPS Forwarding Rule (Frontend)
resource "google_compute_global_forwarding_rule" "lb_forwarding_rule_https" {
  name                  = "${var.lb_forwarding_rule_name}-https"
  target                = google_compute_target_https_proxy.lb_https_proxy.id
  port_range            = "443"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb_external_ip.address
}

# 输出信息 - Load Balancer 详情
output "load_balancer_info" {
  value = {
    name        = var.lb_name
    external_ip = google_compute_global_address.lb_external_ip.address
    # 80 端口服务
    forwarding_rule_80 = google_compute_global_forwarding_rule.lb_forwarding_rule.name
    backend_service_80 = google_compute_backend_service.global_backend.name
    health_check_80    = google_compute_health_check.backend_health_check.name
    url_map_80         = google_compute_url_map.lb_url_map.name
    http_proxy_80      = google_compute_target_http_proxy.lb_http_proxy.name
    access_url_80      = "http://${google_compute_global_address.lb_external_ip.address}:80"
    # 8000 端口服务
    forwarding_rule_8000 = google_compute_global_forwarding_rule.lb_forwarding_rule_8000.name
    backend_service_8000 = google_compute_backend_service.global_backend_8000.name
    health_check_8000    = google_compute_health_check.backend_health_check_8000.name
    url_map_8000         = google_compute_url_map.lb_url_map_8000.name
    http_proxy_8000      = google_compute_target_http_proxy.lb_http_proxy_8000.name
    access_url_8000      = "http://${google_compute_global_address.lb_external_ip.address}:8000"
  }
  description = "Load Balancer configuration details"
}

# 输出信息 - Backend 详情
output "load_balancer_backends" {
  value = {
    for key, backend in var.lb_backends : key => {
      instance_group      = backend.instance_group_key
      instance_group_link = google_compute_instance_group.instance_groups[backend.instance_group_key].self_link
      balancing_mode      = backend.balancing_mode
      capacity_scaler     = backend.capacity_scaler
    }
  }
  description = "Load Balancer backend configuration"
}
