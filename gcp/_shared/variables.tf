# Shared variable declarations for all environments
# Full type definitions are in gcp/variables.tf
# Values are provided via terraform.tfvars

variable "env" {
  description = "Environment name (e.g. dev, test, prod)"
  type        = string
}

variable "labels" {
  description = "Labels applied to all resources"
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

variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "subnets" {
  description = "List of subnet configurations"
  type        = any # Full type definition in gcp/variables.tf
}

variable "firewalls" {
  description = "Firewall rules for this environment"
  type        = any # Full type definition in gcp/variables.tf
  default     = []
}

variable "nats" {
  description = "List of NAT configurations"
  type        = any # Full type definition in gcp/variables.tf
  default     = []
}

variable "iam_bindings" {
  description = "Project-level IAM bindings"
  type        = any # Full type definition in gcp/variables.tf
  default     = []
}

variable "service_accounts" {
  description = "Service accounts to create"
  type        = any # Full type definition in gcp/variables.tf
  default     = []
}

variable "buckets" {
  description = "List of GCS buckets to create"
  type        = any # Full type definition in gcp/variables.tf
  default     = []
}

variable "instances" {
  description = "List of VM instances to create"
  type        = any # Full type definition in gcp/variables.tf
  default     = []
}

variable "instance_groups" {
  description = "List of instance groups to create"
  type        = any # Full type definition in gcp/variables.tf
  default     = []
}

variable "load_balancers" {
  description = "List of load balancer configurations"
  type        = any # Full type definition in gcp/variables.tf
  default     = []
}
