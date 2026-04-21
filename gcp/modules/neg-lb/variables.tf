variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "neg_load_balancers" {
  description = "List of load balancer configurations using GKE Standalone NEG backends"
  type = list(object({
    name                = string
    description         = optional(string)
    global_address_name = optional(string) # Name of the global address to use (allows sharing IP between LBs)

    # Port configuration
    http_port  = optional(number, 80)
    https_port = optional(number, 443)

    # Health check configuration (HTTP by default for NEG pod-level checks)
    health_check = object({
      name                = string
      type                = optional(string, "HTTP") # HTTP or TCP
      check_interval_sec  = optional(number, 15)
      timeout_sec         = optional(number, 5)
      healthy_threshold   = optional(number, 2)
      unhealthy_threshold = optional(number, 3)
      port                = optional(number, 80)
      # HTTP specific
      request_path = optional(string, "/")
    })

    # Backend service configuration
    backend_service = object({
      name                  = string
      protocol              = optional(string, "HTTP")
      timeout_sec           = optional(number, 30)
      enable_cdn            = optional(bool, false)
      session_affinity      = optional(string, "NONE")
      balancing_mode        = optional(string, "RATE")
      max_rate_per_endpoint = optional(number, 1000) # For RATE mode
      max_utilization       = optional(number, 0.8)  # For UTILIZATION mode
      security_policy       = optional(string)
      enable_logging        = optional(bool, false)
      log_sample_rate       = optional(number, 1.0)

      # NEG backends: name + zone pairs
      # NEGs are created by GKE NEG controller when K8s Service has cloud.google.com/neg annotation
      # Deploy Helm charts first, then populate these values from: gcloud compute network-endpoint-groups list
      negs = list(object({
        name = string
        zone = string
      }))
    })

    # SSL configuration (optional, uses GCP-managed certificates)
    ssl_config = optional(object({
      enabled             = bool
      certificate_domains = list(string)
    }))
  }))
  default = []
}
