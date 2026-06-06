variable "lambda_functions" {
  description = "Lambda functions to deploy. Source is zipped from a local directory relative to the root module (env dir)."
  type = list(object({
    name         = string
    runtime      = string
    handler      = string
    source_dir   = string # relative to the root module (env dir)
    memory_mb    = optional(number, 128)
    timeout_s    = optional(number, 3)
    architecture = optional(string, "x86_64") # x86_64 or arm64

    environment_variables = optional(map(string), {})

    role_name = string # references key in var.lambda_role_arns

    function_url = optional(object({
      enabled   = optional(bool, true)
      auth_type = optional(string, "AWS_IAM") # NONE or AWS_IAM

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

  validation {
    condition = alltrue([
      for f in var.lambda_functions : contains(["x86_64", "arm64"], coalesce(f.architecture, "x86_64"))
    ])
    error_message = "architecture must be x86_64 or arm64."
  }

  validation {
    condition = alltrue([
      for f in var.lambda_functions :
      f.function_url == null || contains(["NONE", "AWS_IAM"], coalesce(f.function_url.auth_type, "AWS_IAM"))
    ])
    error_message = "function_url.auth_type must be NONE or AWS_IAM."
  }
}

variable "lambda_role_arns" {
  description = "Map of Lambda role alias -> role ARN, supplied by the iam module."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
