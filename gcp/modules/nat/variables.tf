variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "nat_configs" {
  description = "List of NAT configurations"
  type = list(object({
    name                               = string
    router_name                        = string
    network                            = string
    region                             = string
    source_subnetwork_ip_ranges_to_nat = optional(string, "ALL_SUBNETWORKS_ALL_IP_RANGES")
    nat_ip_allocate_option             = optional(string, "AUTO_ONLY")
    min_ports_per_vm                   = optional(number, 64)
    max_ports_per_vm                   = optional(number, 65536)
    enable_endpoint_independent_mapping = optional(bool, false)
    log_config = optional(object({
      enable = bool
      filter = string
    }))
  }))
  default = []
}
