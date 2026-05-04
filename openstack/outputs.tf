output "networks" {
  description = "Tenant networks keyed by name"
  value       = module.network.networks
}

output "subnets" {
  description = "Subnets keyed by network-name/subnet-name"
  value       = module.network.subnets
}

output "routers" {
  description = "Routers keyed by name"
  value       = module.network.routers
}

output "security_groups" {
  description = "Security groups keyed by name"
  value       = module.network.security_groups
}

output "floating_ips" {
  description = "Floating IPs keyed by name"
  value       = module.network.floating_ips
}

output "keypairs" {
  description = "Keypairs keyed by name"
  value       = module.compute.keypairs
}

output "instances" {
  description = "Instances keyed by name"
  value       = module.compute.instances
}

output "volumes" {
  description = "Volumes keyed by name"
  value       = module.storage.volumes
}
