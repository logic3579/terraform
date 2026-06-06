# Shared variable declarations for all environments
# Full type definitions are in aws/variables.tf
# Values are provided via terraform.tfvars

variable "env" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "aws_profile" {
  description = "AWS named profile for provider authentication. Leave null to use the default credential chain (AWS_PROFILE env var, [default] profile, static env vars, EC2 instance role, etc.)."
  type        = string
  default     = null
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

variable "ec2_instance_profiles" {
  description = "EC2 IAM roles + instance profiles"
  type        = any
  default     = []
}

variable "lambda_execution_roles" {
  description = "Lambda execution IAM roles"
  type        = any
  default     = []
}

variable "key_pairs" {
  description = "SSH key pairs"
  type        = any
  default     = []
}

variable "instances" {
  description = "EC2 instances"
  type        = any
  default     = []
}

variable "rds_instances" {
  description = "RDS instances"
  type        = any
  default     = []
}

variable "lambda_functions" {
  description = "Lambda functions"
  type        = any
  default     = []
}

variable "budgets" {
  description = "AWS Budgets"
  type        = any
  default     = []
}
