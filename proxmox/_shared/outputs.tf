# Shared outputs forwarded from the root module

output "bridges" {
  description = "Linux bridges keyed by node_name/bridge_name"
  value       = module.proxmox.bridges
}

output "download_files" {
  description = "Downloaded files keyed by name"
  value       = module.proxmox.download_files
}

output "vms" {
  description = "VMs keyed by name"
  value       = module.proxmox.vms
}
