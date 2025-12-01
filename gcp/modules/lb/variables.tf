variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "load_balancers" {
  description = "List of load balancer configurations"
  type = list(object({
    name                = string
    description         = optional(string)
    global_address_name = optional(string) # Name of the global address to use (allows sharing IP between LBs)

    # Port configuration
    http_port  = optional(number, 80)
    https_port = optional(number, 443)

    # Health check configuration (TCP)
    health_check = object({
      name                = string
      check_interval_sec  = optional(number, 5)
      timeout_sec         = optional(number, 5)
      healthy_threshold   = optional(number, 2)
      unhealthy_threshold = optional(number, 2)
      port                = optional(number, 80)
    })

    # Backend service configuration
    backend_service = object({
      name                  = string
      protocol              = optional(string, "HTTP")
      port_name             = optional(string, "http")
      timeout_sec           = optional(number, 30)
      enable_cdn            = optional(bool, false)
      session_affinity      = optional(string, "NONE")
      balancing_mode        = optional(string, "UTILIZATION") # UTILIZATION or RATE
      max_utilization       = optional(number, 0.8)
      max_rate_per_instance = optional(number)
      instance_groups       = list(string)          # List of instance group self_links
      security_policy       = optional(string)      # Cloud Armor security policy (null to disable)
      enable_logging        = optional(bool, false) # Enable access logging
      log_sample_rate       = optional(number, 1.0) # Log sampling rate (0.0-1.0)
    })

    # SSL configuration (optional)
    ssl_config = optional(object({
      enabled             = bool
      certificate_domains = list(string)
      private_key         = optional(string)
      certificate         = optional(string)
    }))
  }))
  default = []
}
