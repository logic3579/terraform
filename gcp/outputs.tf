output "network_name" {
  description = "VPC network name"
  value       = module.network.network_name
}

output "subnets" {
  description = "List of subnets created by the network module"
  value       = module.network.subnets
}

output "service_accounts" {
  description = "Service accounts created by the IAM module"
  value       = module.iam.service_accounts
}

# GCE module is currently disabled in root main.tf; keep related outputs commented
# output "instances" {
#   description = "GCE instances created by the GCE module"
#   value       = module.gce.instances
# }
#
# output "instance_groups" {
#   description = "Instance groups created by the GCE module"
#   value       = module.gce.instance_groups
# }
