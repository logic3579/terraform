variable "vpcs" {
  description = "List of VPC configurations with subnets, NAT gateways, and security groups"
  type = list(object({
    name       = string
    cidr_block = string
    tags       = optional(map(string), {})

    subnets = optional(list(object({
      name              = string
      cidr_block        = string
      availability_zone = string
      public            = optional(bool, false)
      nat_gateway_name  = optional(string)
      tags              = optional(map(string), {})
    })), [])

    nat_gateways = optional(list(object({
      name        = string
      subnet_name = string
      tags        = optional(map(string), {})
    })), [])

    security_groups = optional(list(object({
      name        = string
      description = optional(string, "Managed by Terraform")
      tags        = optional(map(string), {})

      ingress_rules = optional(list(object({
        description = optional(string, "")
        from_port   = number
        to_port     = number
        protocol    = string
        cidr_blocks = optional(list(string), [])
      })), [])

      egress_rules = optional(list(object({
        description = optional(string, "")
        from_port   = number
        to_port     = number
        protocol    = string
        cidr_blocks = optional(list(string), [])
      })), [])
    })), [])
  }))
  default = []
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
