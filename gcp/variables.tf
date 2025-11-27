variable "env" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
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
  description = "Default GCE zone for compute resources"
  type        = string
}

variable "subnets" {
  description = "List of subnet configurations"
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
  description = "Service accounts to create at project level"
  type = list(object({
    account_id   = string
    display_name = string
  }))
  default = []
}

variable "instances" {
  description = "GCE instance definitions"
  type = list(object({
    name                  = string
    machine_type          = string
    zone                  = optional(string)
    tags                  = optional(list(string))
    labels                = optional(map(string))
    service_account_email = optional(string)
    metadata              = optional(map(string))
  }))
  default = []
}

variable "instance_groups" {
  description = "Instance groups definitions referencing existing instances by name"
  type = list(object({
    name      = string
    zone      = string
    instances = list(string)
  }))
  default = []
}

variable "base_labels" {
  description = "Base labels applied to all resources in this root module"
  type        = map(string)
  default     = {}
}
