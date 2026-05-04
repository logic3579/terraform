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

    memory_dedicated = optional(number, 2048)

    disks = optional(list(object({
      interface    = string
      datastore_id = string
      size         = number
      file_format  = optional(string, "raw")
      file_id      = optional(string)
    })), [])

    network_devices = optional(list(object({
      bridge  = string
      model   = optional(string, "virtio")
      vlan_id = optional(number)
    })), [])

    cloud_init = optional(object({
      datastore_id = optional(string)
      username     = optional(string)
      password     = optional(string)
      ssh_keys     = optional(list(string), [])
      ipv4_address = optional(string)
      ipv4_gateway = optional(string)
      dns_servers  = optional(list(string), [])
      dns_domain   = optional(string)
    }))

    agent_enabled = optional(bool, true)
  }))
  default = []
}
