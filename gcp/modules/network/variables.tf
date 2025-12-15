variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "networks" {
  description = "List of VPC network configurations with their subnets and firewalls"
  type = list(object({
    name = string
    subnets = optional(list(object({
      name   = string
      cidr   = string
      region = string
    })), [])
    firewalls = optional(list(object({
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
    })), [])
  }))
  default = []
}
