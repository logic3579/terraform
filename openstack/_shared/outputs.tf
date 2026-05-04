# Shared outputs forwarded from the root module

output "networks" {
  value = module.openstack.networks
}

output "subnets" {
  value = module.openstack.subnets
}

output "routers" {
  value = module.openstack.routers
}

output "security_groups" {
  value = module.openstack.security_groups
}

output "floating_ips" {
  value = module.openstack.floating_ips
}

output "keypairs" {
  value = module.openstack.keypairs
}

output "instances" {
  value = module.openstack.instances
}

output "volumes" {
  value = module.openstack.volumes
}
