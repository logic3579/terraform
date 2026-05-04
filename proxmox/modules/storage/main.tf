resource "proxmox_virtual_environment_download_file" "this" {
  for_each = { for f in var.download_files : f.name => f }

  node_name          = each.value.node_name
  datastore_id       = each.value.datastore_id
  content_type       = each.value.content_type
  url                = each.value.url
  file_name          = each.value.file_name
  checksum           = each.value.checksum
  checksum_algorithm = each.value.checksum_algorithm
  overwrite          = each.value.overwrite
}
