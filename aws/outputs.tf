# ============================================================
# Network outputs
# ============================================================

output "vpcs" {
  description = "Map of VPC resources keyed by VPC name"
  value       = module.network.vpcs
}

output "subnets" {
  description = "Map of subnet resources keyed by vpc-name/subnet-name"
  value       = module.network.subnets
}

output "internet_gateways" {
  description = "Map of internet gateways keyed by VPC name"
  value       = module.network.internet_gateways
}

output "nat_gateways" {
  description = "Map of NAT gateways keyed by vpc-name/nat-name"
  value       = module.network.nat_gateways
}

output "security_groups" {
  description = "Map of security groups keyed by vpc-name/sg-name"
  value       = module.network.security_groups
}

# ============================================================
# IAM outputs
# ============================================================

output "ec2_instance_profile_names" {
  description = "Map of EC2 instance profile alias -> actual profile name"
  value       = module.iam.ec2_instance_profile_names
}

output "ec2_role_arns" {
  description = "Map of EC2 role alias -> role ARN"
  value       = module.iam.ec2_role_arns
}

output "lambda_role_arns" {
  description = "Map of Lambda role alias -> role ARN"
  value       = module.iam.lambda_role_arns
}

output "iam_user_arns" {
  description = "Map of IAM user name -> ARN"
  value       = module.iam.iam_user_arns
}

output "iam_user_names" {
  description = "Map of IAM user alias -> actual user name"
  value       = module.iam.iam_user_names
}

# ============================================================
# Compute outputs
# ============================================================

output "instances" {
  description = "Map of EC2 instances keyed by name"
  value       = module.compute.instances
}

output "elastic_ips" {
  description = "Map of Elastic IPs keyed by instance name"
  value       = module.compute.elastic_ips
}

output "key_pairs" {
  description = "Map of key pairs keyed by key name"
  value       = module.compute.key_pairs
}

# ============================================================
# RDS outputs
# ============================================================

output "rds_instances" {
  description = "Map of RDS instances keyed by name"
  value       = module.rds.rds_instances
}

output "ssm_password_parameters" {
  description = "Map of SSM Parameter Store paths for RDS master passwords"
  value       = module.rds.ssm_password_parameters
}

# ============================================================
# Lambda outputs
# ============================================================

output "lambda_functions" {
  description = "Map of Lambda functions keyed by name"
  value       = module.lambda.lambda_functions
}

output "function_urls" {
  description = "Map of Lambda Function URLs keyed by function name"
  value       = module.lambda.function_urls
}

# ============================================================
# Budget outputs
# ============================================================

output "budgets" {
  description = "Map of Budgets keyed by name"
  value       = module.budget.budgets
}
