variable "env" {
  description = "Environment name"
  type        = string
}

variable "labels" {
  description = "Labels for this environment"
  type        = map(string)
  default     = {}
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "zone" {
  description = "Default GCE zone"
  type        = string
}

variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "subnets" {
  description = "Subnets for this environment"
  type = list(object({
    name   = string
    cidr   = string
    region = string
  }))
}

variable "firewalls" {
  description = "Firewall rules for this environment"
  type = list(object({
    name                    = string
    description             = optional(string)
    direction               = string
    priority                = optional(number)
    source_ranges           = optional(list(string))
    destination_ranges      = optional(list(string))
    source_tags             = optional(list(string))
    target_tags             = optional(list(string))
    target_service_accounts = optional(list(string))
    allow = list(object({
      protocol = string
      ports    = optional(list(string))
    }))
    disabled = optional(bool)
  }))
  default = []
}

variable "nat_configs" {
  description = "List of NAT configurations"
  type = list(object({
    name                                = string
    router_name                         = string
    network                             = string
    region                              = string
    source_subnetwork_ip_ranges_to_nat  = optional(string, "ALL_SUBNETWORKS_ALL_IP_RANGES")
    nat_ip_allocate_option              = optional(string, "AUTO_ONLY")
    min_ports_per_vm                    = optional(number, 64)
    max_ports_per_vm                    = optional(number, 65536)
    enable_endpoint_independent_mapping = optional(bool, false)
    log_config = optional(object({
      enable = bool
      filter = string
    }))
  }))
  default = []
}

variable "iam_bindings" {
  description = "Project-level IAM bindings"
  type = list(object({
    service_account_email = string
    roles                 = list(string)
  }))
  default = []
}

variable "service_accounts" {
  description = "Service accounts to create"
  type = list(object({
    account_id   = string
    display_name = string
  }))
  default = []
}

variable "gcs_buckets" {
  description = "List of GCS buckets to create"
  type = list(object({
    name                     = string
    location                 = string
    storage_class            = optional(string)
    public_access_prevention = optional(string)
    versioning_enabled       = optional(bool)
    labels                   = optional(map(string))
    lifecycle_rules = optional(list(object({
      action = object({
        type          = string
        storage_class = optional(string)
      })
      condition = object({
        age        = optional(number)
        with_state = optional(string)
      })
    })))
  }))
  default = []
}

variable "vm_instances" {
  description = "List of VM instances to create"
  type = list(object({
    name          = string
    machine_type  = string
    region        = string
    zone          = string
    network_tags  = optional(list(string))
    external_ip   = optional(bool, false)
    image_family  = string
    image_project = string
    disk_size     = number
    disk_type     = string
    network       = string
    subnetwork    = string
  }))
  default = []
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


