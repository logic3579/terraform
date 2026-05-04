variable "bridges" {
  description = "Linux bridges on Proxmox nodes"
  type = list(object({
    node_name  = string
    name       = string
    address    = optional(string)
    gateway    = optional(string)
    comment    = optional(string)
    ports      = optional(list(string), [])
    vlan_aware = optional(bool, false)
    mtu        = optional(number)
  }))
  default = []
}
