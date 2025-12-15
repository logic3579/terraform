variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "service_accounts" {
  description = "Service accounts to create"
  type = list(object({
    account_id   = string
    display_name = string
    description  = optional(string)
  }))
  default = []
}

variable "iam_bindings" {
  description = "Project-level IAM bindings per service account"
  type = list(object({
    service_account_email = string
    roles                 = list(string)
  }))
  default = []
}
