output "networks" {
  description = "Map of VPC networks"
  value       = module.network.networks
}

output "subnets" {
  description = "Map of subnets created by the network module"
  value       = module.network.subnets
}

output "firewalls" {
  description = "Map of firewall rules"
  value       = module.network.firewalls
}

output "nat_router_names" {
  description = "NAT router names"
  value       = module.nat.router_names
}

output "nat_names" {
  description = "NAT configuration names"
  value       = module.nat.nat_names
}

output "lb_ip_addresses" {
  description = "Load balancer IP addresses"
  value       = module.lb.lb_ip_addresses
}

output "lb_urls" {
  description = "Load balancer URLs"
  value       = module.lb.lb_urls
}

output "service_accounts" {
  description = "Service accounts created by the IAM module"
  value       = module.iam.service_accounts
}

output "bucket_names" {
  description = "GCS bucket names"
  value       = module.storage.bucket_names
}

output "bucket_urls" {
  description = "GCS bucket URLs"
  value       = module.storage.bucket_urls
}

output "bucket_iam_bindings" {
  description = "GCS bucket IAM member bindings"
  value       = module.storage.bucket_iam_bindings
}

output "instance_names" {
  description = "VM instance names"
  value       = module.compute.instance_names
}

output "instance_ips" {
  description = "VM instance external IPs"
  value       = module.compute.instance_ips
}

output "instance_group_names" {
  description = "Instance group names"
  value       = module.compute.instance_group_names
}

output "disk_names" {
  description = "Additional disk names (new disks only)"
  value       = module.compute.disk_names
}
