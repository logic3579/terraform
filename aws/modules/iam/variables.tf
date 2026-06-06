variable "ec2_instance_profiles" {
  description = "EC2 IAM roles + instance profiles (one role per profile). Inline policies are a map of policy-name -> JSON policy document."
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
  description = "Lambda execution IAM roles. Inline policies are a map of policy-name -> JSON policy document."
  type = list(object({
    name                = string
    description         = optional(string, "Managed by Terraform")
    managed_policy_arns = optional(list(string), [])
    inline_policies     = optional(map(string), {})
    tags                = optional(map(string), {})
  }))
  default = []
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
