variable "env" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

# ============================================================
# Network resources
# ============================================================

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

  validation {
    condition = alltrue([
      for vpc in var.vpcs :
      can(cidrhost(vpc.cidr_block, 0))
    ])
    error_message = "All VPC CIDR blocks must be valid CIDR notation (e.g., 10.0.0.0/16)."
  }

  validation {
    condition = alltrue(flatten([
      for vpc in var.vpcs : [
        for subnet in coalesce(vpc.subnets, []) :
        can(cidrhost(subnet.cidr_block, 0))
      ]
    ]))
    error_message = "All subnet CIDR blocks must be valid CIDR notation (e.g., 10.0.1.0/24)."
  }

  validation {
    condition = alltrue(flatten([
      for vpc in var.vpcs : [
        for nat in coalesce(vpc.nat_gateways, []) :
        contains([for s in coalesce(vpc.subnets, []) : s.name if coalesce(s.public, false)], nat.subnet_name)
      ]
    ]))
    error_message = "NAT gateways must reference a public subnet (subnet with public = true)."
  }
}
