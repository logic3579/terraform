# Shared variable declarations for all environments
# Full type definitions are in aws/variables.tf
# Values are provided via terraform.tfvars

variable "env" {
  description = "Environment name (e.g. devtest, prod)"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "vpcs" {
  description = "List of VPC configurations with subnets, NAT gateways, and security groups"
  type        = any # Full type definition in aws/variables.tf
  default     = []
}
