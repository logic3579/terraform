variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "vm_instances" {
  description = "List of VM instances to create"
  type = list(object({
    name                  = string
    machine_type          = string
    region                = string
    zone                  = string
    image_family          = string
    image_project         = string
    disk_size             = number
    disk_type             = string
    network_tags          = optional(list(string))
    external_ip           = optional(bool, false)
    network               = string
    subnetwork            = string
    service_account_email = optional(string, "xxx-compute@developer.gserviceaccount.com")
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
