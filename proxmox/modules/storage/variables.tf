variable "download_files" {
  description = "ISOs / images / LXC templates downloaded into PVE datastores"
  type = list(object({
    name               = string
    node_name          = string
    datastore_id       = string
    content_type       = string
    url                = string
    file_name          = optional(string)
    checksum           = optional(string)
    checksum_algorithm = optional(string)
    overwrite          = optional(bool, false)
  }))
  default = []
}
