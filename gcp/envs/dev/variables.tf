variable "env" {
  description = "Environment name"
  type        = string
}

variable "labels" {
  description = "Labels for this environment"
  type        = map(string)
  default     = {}
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "zone" {
  description = "Default GCE zone"
  type        = string
}

variable "subnets" {
  description = "Subnets for this environment"
  type = list(object({
    name   = string
    cidr   = string
    region = string
  }))
}

variable "iam_bindings" {
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
