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
