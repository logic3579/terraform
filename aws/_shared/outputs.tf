# Shared output definitions for all environments
# These outputs forward values from the root module

output "vpcs" {
  description = "Map of VPC resources keyed by VPC name"
  value       = module.aws.vpcs
}

output "subnets" {
  description = "Map of subnet resources keyed by vpc-name/subnet-name"
  value       = module.aws.subnets
}

output "internet_gateways" {
  description = "Map of internet gateways keyed by VPC name"
  value       = module.aws.internet_gateways
}

output "nat_gateways" {
  description = "Map of NAT gateways keyed by vpc-name/nat-name"
  value       = module.aws.nat_gateways
}

output "security_groups" {
  description = "Map of security groups keyed by vpc-name/sg-name"
  value       = module.aws.security_groups
}

# ============================================================
# IAM
# ============================================================

output "ec2_instance_profile_names" {
  description = "Map of EC2 instance profile alias -> actual profile name"
  value       = module.aws.ec2_instance_profile_names
}

output "ec2_role_arns" {
  description = "Map of EC2 role alias -> role ARN"
  value       = module.aws.ec2_role_arns
}

output "lambda_role_arns" {
  description = "Map of Lambda role alias -> role ARN"
  value       = module.aws.lambda_role_arns
}

# ============================================================
# Compute
# ============================================================

output "instances" {
  description = "Map of EC2 instances keyed by name"
  value       = module.aws.instances
}

output "elastic_ips" {
  description = "Map of Elastic IPs keyed by instance name"
  value       = module.aws.elastic_ips
}

output "key_pairs" {
  description = "Map of key pairs keyed by key name"
  value       = module.aws.key_pairs
}

# ============================================================
# RDS
# ============================================================

output "rds_instances" {
  description = "Map of RDS instances keyed by name (master password is in SSM Parameter Store, see ssm_password_path)"
  value       = module.aws.rds_instances
}

output "ssm_password_parameters" {
  description = "Map of SSM Parameter Store paths for RDS master passwords"
  value       = module.aws.ssm_password_parameters
}

# ============================================================
# Lambda
# ============================================================

output "lambda_functions" {
  description = "Map of Lambda functions keyed by name"
  value       = module.aws.lambda_functions
}

output "function_urls" {
  description = "Map of Lambda Function URLs keyed by function name"
  value       = module.aws.function_urls
}

# ============================================================
# Budgets
# ============================================================

output "budgets" {
  description = "Map of Budgets keyed by name"
  value       = module.aws.budgets
}
