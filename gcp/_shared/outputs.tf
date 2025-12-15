# Shared output definitions for all environments
# These outputs forward values from the root module

output "networks" {
  description = "Map of VPC networks"
  value       = module.gcp.networks
}

output "subnets" {
  description = "Map of subnets"
  value       = module.gcp.subnets
}

output "firewalls" {
  description = "Map of firewall rules"
  value       = module.gcp.firewalls
}

output "nat_router_names" {
  description = "NAT router names"
  value       = module.gcp.nat_router_names
}

output "nat_names" {
  description = "NAT configuration names"
  value       = module.gcp.nat_names
}

output "lb_ip_addresses" {
  description = "Load balancer IP addresses"
  value       = module.gcp.lb_ip_addresses
}

output "lb_urls" {
  description = "Load balancer URLs"
  value       = module.gcp.lb_urls
}

output "service_accounts" {
  description = "Service accounts"
  value       = module.gcp.service_accounts
}

output "bucket_names" {
  description = "GCS bucket names"
  value       = module.gcp.bucket_names
}

output "bucket_urls" {
  description = "GCS bucket URLs"
  value       = module.gcp.bucket_urls
}

output "instance_names" {
  description = "VM instance names"
  value       = module.gcp.instance_names
}

output "instance_ips" {
  description = "VM instance external IPs"
  value       = module.gcp.instance_ips
}

output "instance_group_names" {
  description = "Instance group names"
  value       = module.gcp.instance_group_names
}
