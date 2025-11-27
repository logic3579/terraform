variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "env" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
}

variable "zone" {
  description = "Default zone for instances"
  type        = string
}

variable "instances" {
  description = "GCE instance definitions"
  type = list(object({
    name                  = string
    machine_type          = string
    zone                  = optional(string)
    tags                  = optional(list(string))
    labels                = optional(map(string))
    service_account_email = optional(string)
    metadata              = optional(map(string))
  }))
  default = []
}

variable "instance_groups" {
  description = "Instance groups definitions referencing existing instances by name"
  type = list(object({
    name      = string
    zone      = string
    instances = list(string)
  }))
  default = []
}

variable "default_labels" {
  description = "Base labels for all compute resources"
  type        = map(string)
  default     = {}
}

variable "boot_disk_image" {
  description = "Boot disk image for instances (e.g. family/debian-11)"
  type        = string
}

variable "subnetwork_self_link" {
  description = "Self link of the subnetwork for primary NIC"
  type        = string
}

variable "default_service_account_email" {
  description = "Default service account email for instances if not overridden"
  type        = string
}
