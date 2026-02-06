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
