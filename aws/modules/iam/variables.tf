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

variable "iam_users" {
  description = "IAM users. Inline policies are a map of policy-name -> JSON policy document. Console login profile and programmatic access keys are intentionally not managed here — create them out-of-band to keep credentials out of state."
  type = list(object({
    name                 = string
    path                 = optional(string, "/")
    permissions_boundary = optional(string)
    managed_policy_arns  = optional(list(string), [])
    inline_policies      = optional(map(string), {})
    tags                 = optional(map(string), {})
  }))
  default = []
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
