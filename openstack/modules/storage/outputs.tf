output "volumes" {
  description = "Volumes keyed by name"
  value = {
    for k, v in openstack_blockstorage_volume_v3.this : k => {
      id   = v.id
      size = v.size
    }
  }
}

output "volume_id_by_name" {
  description = "Map of volume name → id (used by compute module to boot from volume)"
  value       = { for k, v in openstack_blockstorage_volume_v3.this : k => v.id }
}
