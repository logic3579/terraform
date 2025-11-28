output "network_name" {
  description = "VPC network name"
  value       = module.gcp.network_name
}

output "subnets" {
  description = "List of subnets"
  value       = module.gcp.subnets
}

output "nat_router_names" {
  description = "NAT router names"
  value       = module.gcp.nat_router_names
}

output "nat_names" {
  description = "NAT configuration names"
  value       = module.gcp.nat_names
}

output "service_accounts" {
  description = "Service accounts"
  value       = module.gcp.service_accounts
}

output "gcs_bucket_names" {
  description = "GCS bucket names"
  value       = module.gcp.gcs_bucket_names
}

output "gcs_bucket_urls" {
  description = "GCS bucket URLs"
  value       = module.gcp.gcs_bucket_urls
}

output "vm_instance_names" {
  description = "VM instance names"
  value       = module.gcp.vm_instance_names
}

output "vm_instance_ips" {
  description = "VM instance external IPs"
  value       = module.gcp.vm_instance_ips
}

output "instance_group_names" {
  description = "Instance group names"
  value       = module.gcp.instance_group_names
}
