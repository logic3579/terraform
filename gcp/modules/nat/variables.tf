variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "nats" {
  description = "List of NAT configurations"
  type = list(object({
    name                               = string
    router_name                        = string
    network                            = string
    region                             = string
    source_subnetwork_ip_ranges_to_nat = optional(string, "ALL_SUBNETWORKS_ALL_IP_RANGES")
    nat_ip_allocate_option             = optional(string, "AUTO_ONLY")

    # Dynamic Port Allocation (DPA) configuration
    # When enabled, ports are allocated dynamically based on usage
    # Note: Cannot be used with enable_endpoint_independent_mapping = true
    enable_dynamic_port_allocation = optional(bool, false)

    # Port allocation settings
    # - Static (DPA disabled): min_ports_per_vm default is 64
    # - Dynamic (DPA enabled): min_ports_per_vm must be >= 32 and power of 2
    min_ports_per_vm = optional(number, 64)
    max_ports_per_vm = optional(number) # Only used when DPA is enabled

    enable_endpoint_independent_mapping = optional(bool, false)
    log_config = optional(object({
      enable = bool
      filter = string
    }))
  }))
  default = []

  # Validation: DPA and Endpoint-Independent Mapping are mutually exclusive
  validation {
    condition = alltrue([
      for nat in var.nats :
      !(nat.enable_dynamic_port_allocation == true && nat.enable_endpoint_independent_mapping == true)
    ])
    error_message = "enable_dynamic_port_allocation and enable_endpoint_independent_mapping cannot both be true. They are mutually exclusive."
  }

  # Validation: When DPA is enabled, min_ports_per_vm must be >= 32 and power of 2
  validation {
    condition = alltrue([
      for nat in var.nats :
      nat.enable_dynamic_port_allocation != true ||
      (nat.min_ports_per_vm >= 32 && nat.min_ports_per_vm <= 32768 &&
      can(regex("^(32|64|128|256|512|1024|2048|4096|8192|16384|32768)$", tostring(nat.min_ports_per_vm))))
    ])
    error_message = "When enable_dynamic_port_allocation is true, min_ports_per_vm must be a power of 2 between 32 and 32768."
  }
}
