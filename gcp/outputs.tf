output "network_name" {
  description = "VPC network name"
  value       = module.network.network_name
}

output "subnets" {
  description = "List of subnets created by the network module"
  value       = module.network.subnets
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

output "gcs_bucket_names" {
  description = "GCS bucket names"
  value       = module.gcs.bucket_names
}

output "gcs_bucket_urls" {
  description = "GCS bucket URLs"
  value       = module.gcs.bucket_urls
}

output "vm_instance_names" {
  description = "VM instance names"
  value       = module.gce.instance_names
}

output "vm_instance_ips" {
  description = "VM instance external IPs"
  value       = module.gce.instance_ips
}

output "instance_group_names" {
  description = "Instance group names"
  value       = module.gce.instance_group_names
}
