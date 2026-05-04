variable "keypairs" {
  type = list(object({
    name       = string
    public_key = string
  }))
  default = []
}

variable "instances" {
  type = list(object({
    name              = string
    image_name        = optional(string)
    flavor_name       = string
    keypair_name      = optional(string)
    user_data         = optional(string)
    metadata          = optional(map(string), {})
    availability_zone = optional(string)
    security_groups   = optional(list(string), [])

    networks = list(object({
      network_name = string
      fixed_ip_v4  = optional(string)
    }))

    boot_volume_name = optional(string)
  }))
  default = []
}

variable "network_id_by_name" {
  description = "Map of network name → id (provided by network module)"
  type        = map(string)
  default     = {}
}

variable "volume_id_by_name" {
  description = "Map of volume name → id (provided by storage module)"
  type        = map(string)
  default     = {}
}
