output "download_files" {
  description = "Downloaded files keyed by name; .id is usable as VM disk file_id"
  value = {
    for k, v in proxmox_virtual_environment_download_file.this : k => {
      id           = v.id
      file_name    = v.file_name
      datastore_id = v.datastore_id
    }
  }
}
