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

variable "networks" {
  description = "List of VPC network configurations with their subnets and firewalls"
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

variable "workload_identity_bindings" {
  description = "Workload Identity bindings for GKE"
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

variable "neg_load_balancers" {
  description = "List of NEG-based load balancer configurations"
  type        = any # Full type definition in gcp/variables.tf
  default     = []
}

variable "gke_clusters" {
  description = "List of GKE cluster configurations"
  type        = any # Full type definition in gcp/variables.tf
  default     = []
}
