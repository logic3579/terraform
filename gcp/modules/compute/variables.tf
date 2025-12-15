variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "instances" {
  description = "List of VM instances to create"
  type = list(object({
    name          = string
    machine_type  = string
    region        = string
    zone          = string
    image_family  = string
    image_project = string
    disk_size     = number
    disk_type     = string
    network_tags  = list(string)
    external_ip   = optional(bool, false)
    network       = string
    subnetwork    = string

    # Service account configuration
    service_account_email = optional(string) # null = use default Compute Engine SA
    service_account_scopes = optional(list(string), [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append",
    ])

    # Preemptible VM configuration
    preemptible = optional(bool, false)

    # Deletion protection (prevents accidental deletion via API/Console)
    deletion_protection = optional(bool, false)

    # Startup script configuration (choose one)
    startup_script      = optional(string) # Inline script
    startup_script_file = optional(string) # Path to script file
    metadata            = optional(map(string), {})
    labels              = optional(map(string), {})
  }))
  default = []

  validation {
    condition = alltrue([
      for vm in var.instances :
      vm.startup_script == null || vm.startup_script_file == null
    ])
    error_message = "Cannot specify both startup_script and startup_script_file"
  }
}

variable "instance_groups" {
  description = "List of instance groups to create"
  type = list(object({
    name        = string
    description = optional(string)
    zone        = string
    instances   = list(string)
    named_ports = optional(list(object({
      name = string
      port = number
    })))
  }))
  default = []
}
