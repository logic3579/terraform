# Shared outputs forwarded from the root module

output "vpcs" {
  value = module.vultr.vpcs
}

output "firewall_groups" {
  value = module.vultr.firewall_groups
}

output "firewall_rules" {
  value = module.vultr.firewall_rules
}

output "ssh_keys" {
  value = module.vultr.ssh_keys
}

output "startup_scripts" {
  value = module.vultr.startup_scripts
}

output "instances" {
  value = module.vultr.instances
}
