output "bridges" {
  description = "Linux bridges keyed by node_name/bridge_name"
  value       = module.network.bridges
}

output "download_files" {
  description = "Downloaded files keyed by name (use .id as VM disk file_id)"
  value       = module.storage.download_files
}

output "vms" {
  description = "VMs keyed by name"
  value       = module.compute.vms
}
