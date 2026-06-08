output "vpcs" {
  description = "VPCs keyed by name"
  value       = module.network.vpcs
}

output "firewall_groups" {
  description = "Firewall groups keyed by name"
  value       = module.network.firewall_groups
}

output "firewall_rules" {
  description = "Firewall rules keyed by group-name/index"
  value       = module.network.firewall_rules
}

output "ssh_keys" {
  description = "SSH keys keyed by name"
  value       = module.compute.ssh_keys
}

output "startup_scripts" {
  description = "Startup scripts keyed by name"
  value       = module.compute.startup_scripts
}

output "instances" {
  description = "Instances keyed by name"
  value       = module.compute.instances
}
