# Environment-specific variable declarations
# Full type definitions are in gcp/variables.tf
# Values are provided via terraform.tfvars

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

variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "subnets" {
  description = "Subnets for this environment"
  type        = any  # Full type definition in gcp/variables.tf
}

variable "firewalls" {
  description = "Firewall rules for this environment"
  type        = any  # Full type definition in gcp/variables.tf
  default     = []
}

variable "nat_configs" {
  description = "List of NAT configurations"
  type        = any  # Full type definition in gcp/variables.tf
  default     = []
}

variable "iam_bindings" {
  description = "Project-level IAM bindings"
  type        = any  # Full type definition in gcp/variables.tf
  default     = []
}

variable "service_accounts" {
  description = "Service accounts to create"
  type        = any  # Full type definition in gcp/variables.tf
  default     = []
}

variable "gcs_buckets" {
  description = "List of GCS buckets to create"
  type        = any  # Full type definition in gcp/variables.tf
  default     = []
}

variable "vm_instances" {
  description = "List of VM instances to create"
  type        = any  # Full type definition in gcp/variables.tf
  default     = []
}

variable "instance_groups" {
  description = "List of instance groups to create"
  type        = any  # Full type definition in gcp/variables.tf
  default     = []
}

variable "load_balancers" {
  description = "List of load balancer configurations"
  type        = any  # Full type definition in gcp/variables.tf
  default     = []
}
