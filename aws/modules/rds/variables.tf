variable "rds_instances" {
  description = "RDS instances to create. Master password is randomly generated and stored in SSM Parameter Store."
  type = list(object({
    name = string

    engine            = string # postgres, mysql, mariadb
    engine_version    = string
    instance_class    = string
    allocated_storage = optional(number, 20)
    storage_type      = optional(string, "gp3")
    storage_encrypted = optional(bool, true)

    db_name  = string
    username = string
    port     = optional(number)

    subnet_names         = list(string) # network module keys (vpc-name/subnet-name), need >=2 AZs
    security_group_names = list(string) # network module keys (vpc-name/sg-name)

    publicly_accessible   = optional(bool, false)
    multi_az              = optional(bool, false)
    backup_retention_days = optional(number, 0)
    skip_final_snapshot   = optional(bool, true)
    deletion_protection   = optional(bool, false)
    apply_immediately     = optional(bool, true)

    ssm_password_path = optional(string) # default: /<name>/master_password

    tags = optional(map(string), {})
  }))
  default = []

  validation {
    condition = alltrue([
      for r in var.rds_instances : contains(["postgres", "mysql", "mariadb"], r.engine)
    ])
    error_message = "engine must be one of: postgres, mysql, mariadb."
  }

  validation {
    condition = alltrue([
      for r in var.rds_instances : length(r.subnet_names) >= 2
    ])
    error_message = "Each RDS instance needs at least 2 subnets (in different AZs) for the DB subnet group."
  }
}

variable "subnet_ids_by_name" {
  description = "Map of subnet name (vpc-name/subnet-name) -> subnet ID, supplied by the network module."
  type        = map(string)
  default     = {}
}

variable "security_group_ids_by_name" {
  description = "Map of security group name (vpc-name/sg-name) -> SG ID, supplied by the network module."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
