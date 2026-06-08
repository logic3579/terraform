variable "vpcs" {
  description = "VPCs (vultr_vpc — vpc2 is deprecated upstream)"
  type = list(object({
    name           = string
    region         = string
    description    = optional(string)
    v4_subnet      = optional(string)
    v4_subnet_mask = optional(number)
  }))
  default = []
}

variable "firewall_groups" {
  description = "Firewall groups and their rules"
  type = list(object({
    name        = string
    description = optional(string)
    rules = optional(list(object({
      protocol    = string
      ip_type     = optional(string, "v4")
      subnet      = string
      subnet_size = number
      port        = optional(string)
      notes       = optional(string)
      source      = optional(string)
    })), [])
  }))
  default = []
}
