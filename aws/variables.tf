variable "env" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.region))
    error_message = "Region must be a valid AWS region format (e.g., us-east-1, ap-southeast-2)."
  }
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

# ============================================================
# IAM resources
# ============================================================

variable "ec2_instance_profiles" {
  description = "EC2 IAM roles + instance profiles. Each entry produces one role and one instance profile of the same name, with the listed managed policies attached."
  type = list(object({
    name                = string
    description         = optional(string, "Managed by Terraform")
    managed_policy_arns = optional(list(string), [])
    inline_policies     = optional(map(string), {})
    tags                = optional(map(string), {})
  }))
  default = []
}

variable "lambda_execution_roles" {
  description = "Lambda execution IAM roles."
  type = list(object({
    name                = string
    description         = optional(string, "Managed by Terraform")
    managed_policy_arns = optional(list(string), [])
    inline_policies     = optional(map(string), {})
    tags                = optional(map(string), {})
  }))
  default = []
}

# ============================================================
# EC2 / Compute resources
# ============================================================

variable "key_pairs" {
  description = "SSH key pairs to register in this region."
  type = list(object({
    name       = string
    public_key = string
  }))
  default = []
}

variable "instances" {
  description = "EC2 instances. References subnets and security groups by their network-module keys (vpc-name/subnet-name)."
  type = list(object({
    name = string

    ami_id = optional(string)
    os     = optional(string) # debian-12, al2023, ubuntu-22

    instance_type = optional(string, "t3.micro")

    subnet_name          = string
    security_group_names = optional(list(string), [])

    associate_public_ip  = optional(bool, true)
    key_name             = optional(string)
    iam_instance_profile = optional(string)
    user_data            = optional(string)

    root_volume = optional(object({
      size_gb               = optional(number, 30)
      type                  = optional(string, "gp3")
      delete_on_termination = optional(bool, true)
      encrypted             = optional(bool, true)
    }), {})

    eip = optional(bool, false)

    tags = optional(map(string), {})
  }))
  default = []
}

# ============================================================
# RDS resources
# ============================================================

variable "rds_instances" {
  description = "RDS instances. Master password is randomly generated and stored in SSM Parameter Store."
  type = list(object({
    name = string

    engine            = string
    engine_version    = string
    instance_class    = string
    allocated_storage = optional(number, 20)
    storage_type      = optional(string, "gp3")
    storage_encrypted = optional(bool, true)

    db_name  = string
    username = string
    port     = optional(number)

    subnet_names         = list(string)
    security_group_names = list(string)

    publicly_accessible   = optional(bool, false)
    multi_az              = optional(bool, false)
    backup_retention_days = optional(number, 0)
    skip_final_snapshot   = optional(bool, true)
    deletion_protection   = optional(bool, false)
    apply_immediately     = optional(bool, true)

    ssm_password_path = optional(string)

    tags = optional(map(string), {})
  }))
  default = []
}

# ============================================================
# Lambda functions
# ============================================================

variable "lambda_functions" {
  description = "Lambda functions packaged from a local source directory (relative to the env dir)."
  type = list(object({
    name         = string
    runtime      = string
    handler      = string
    source_dir   = string
    memory_mb    = optional(number, 128)
    timeout_s    = optional(number, 3)
    architecture = optional(string, "x86_64")

    environment_variables = optional(map(string), {})

    role_name = string

    function_url = optional(object({
      enabled   = optional(bool, true)
      auth_type = optional(string, "AWS_IAM")
      cors = optional(object({
        allow_origins = optional(list(string), [])
        allow_methods = optional(list(string), [])
        allow_headers = optional(list(string), [])
        max_age       = optional(number, 0)
      }))
    }))

    tags = optional(map(string), {})
  }))
  default = []
}

# ============================================================
# AWS Budgets
# ============================================================

variable "budgets" {
  description = "AWS Budgets with email notifications."
  type = list(object({
    name         = string
    budget_type  = optional(string, "COST")
    limit_amount = string
    limit_unit   = optional(string, "USD")
    time_unit    = optional(string, "MONTHLY")

    cost_filters = optional(map(list(string)), {})

    notifications = list(object({
      comparison_operator        = optional(string, "GREATER_THAN")
      threshold                  = number
      threshold_type             = optional(string, "PERCENTAGE")
      notification_type          = optional(string, "ACTUAL")
      subscriber_email_addresses = list(string)
    }))

    tags = optional(map(string), {})
  }))
  default = []
}
