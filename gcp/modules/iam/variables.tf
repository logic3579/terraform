variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "bindings" {
  description = "Project-level IAM bindings"
  type = list(object({
    role    = string
    members = list(string)
  }))
  default = []
}

variable "service_accounts" {
  description = "Service accounts to create"
  type = list(object({
    account_id   = string
    display_name = string
  }))
  default = []
}
