variable "bridges" {
  description = "Linux bridges to create on Proxmox nodes (vmbrN)"
  type = list(object({
    node_name  = string
    name       = string           # e.g. vmbr1
    address    = optional(string) # CIDR, e.g. 10.0.0.1/24
    gateway    = optional(string)
    comment    = optional(string)
    ports      = optional(list(string), []) # physical NICs attached to the bridge
    vlan_aware = optional(bool, false)
    mtu        = optional(number)
  }))
  default = []

  validation {
    condition     = alltrue([for b in var.bridges : can(regex("^vmbr\\d+$", b.name))])
    error_message = "Bridge name must match 'vmbr<N>' (e.g. vmbr0, vmbr1)."
  }
}

variable "download_files" {
  description = "ISOs / cloud images / LXC templates to download into a PVE datastore"
  type = list(object({
    name               = string # logical map key
    node_name          = string
    datastore_id       = string # e.g. local
    content_type       = string # iso | vztmpl
    url                = string
    file_name          = optional(string)
    checksum           = optional(string)
    checksum_algorithm = optional(string) # sha256 | sha512 | md5 | sha1
    overwrite          = optional(bool, false)
  }))
  default = []

  validation {
    condition     = alltrue([for f in var.download_files : contains(["iso", "vztmpl"], f.content_type)])
    error_message = "content_type must be 'iso' or 'vztmpl'."
  }
}

variable "vms" {
  description = "KVM virtual machines"
  type = list(object({
    name        = string
    node_name   = string
    vm_id       = optional(number)
    description = optional(string)
    tags        = optional(list(string), [])
    started     = optional(bool, true)
    on_boot     = optional(bool, true)

    cpu_cores   = optional(number, 2)
    cpu_sockets = optional(number, 1)
    cpu_type    = optional(string, "x86-64-v2-AES")

    memory_dedicated = optional(number, 2048) # MiB

    disks = optional(list(object({
      interface    = string                  # e.g. scsi0, virtio0
      datastore_id = string                  # e.g. local-lvm
      size         = number                  # GiB
      file_format  = optional(string, "raw") # raw | qcow2 | vmdk
      file_id      = optional(string)        # e.g. local:iso/ubuntu.img — to clone from a downloaded image
    })), [])

    network_devices = optional(list(object({
      bridge  = string # e.g. vmbr0
      model   = optional(string, "virtio")
      vlan_id = optional(number)
    })), [])

    cloud_init = optional(object({
      datastore_id = optional(string)
      username     = optional(string)
      password     = optional(string)
      ssh_keys     = optional(list(string), [])
      ipv4_address = optional(string) # "dhcp" or CIDR like 10.0.0.10/24
      ipv4_gateway = optional(string)
      dns_servers  = optional(list(string), [])
      dns_domain   = optional(string)
    }))

    agent_enabled = optional(bool, true)
  }))
  default = []
}
