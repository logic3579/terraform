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
    network_tags  = list(string)
    external_ip   = optional(bool, false)
    image_family  = string
    image_project = string
    disk_size     = number
    disk_type     = string
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

    # Metadata and labels
    metadata = optional(map(string), {})
    labels   = optional(map(string), {})

    # Cloud-init configuration
    cloud_init = optional(object({
      enabled        = bool                 # Enable cloud-init
      hostname       = optional(string)     # Short hostname (FQDN will use GCP default)
      install_docker = optional(bool, true) # Install Docker from official repository (default: true)
      packages = optional(list(string), [
        "htop",
        "net-tools",
        "iputils-ping"
      ])
      additional_config = optional(string, "") # Additional cloud-init YAML
    }))
  }))
  default = []

  # Validation 2: Hostname format validation
  validation {
    condition = alltrue([
      for vm in var.instances :
      vm.cloud_init == null || !vm.cloud_init.enabled ||
      (vm.cloud_init.hostname == null ||
      can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$|^[a-z0-9]$", vm.cloud_init.hostname)))
    ])
    error_message = "cloud_init.hostname must be a valid hostname format (lowercase letters, numbers, hyphens, 1-63 chars)."
  }

  # Validation 3: Package name format validation
  validation {
    condition = alltrue(flatten([
      for vm in var.instances : [
        for pkg in coalesce(vm.cloud_init != null ? vm.cloud_init.packages : null, []) :
        can(regex("^[a-z0-9][a-z0-9+.-]*$", pkg))
      ] if vm.cloud_init != null && vm.cloud_init.enabled
    ]))
    error_message = "Package names must follow valid package naming conventions (lowercase letters, numbers, +, -, .)."
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
