variable "ssh_keys" {
  description = "SSH public keys uploaded to Vultr"
  type = list(object({
    name    = string
    ssh_key = string
  }))
  default = []
}

variable "startup_scripts" {
  description = "Startup scripts (script body must be base64-encoded)"
  type = list(object({
    name   = string
    script = string
    type   = optional(string, "boot")
  }))
  default = []
}

variable "instances" {
  description = "Vultr compute instances"
  type = list(object({
    name   = string
    region = string
    plan   = string

    os_id       = optional(number)
    iso_id      = optional(string)
    app_id      = optional(number)
    image_id    = optional(string)
    snapshot_id = optional(string)

    label    = optional(string)
    hostname = optional(string)
    tags     = optional(list(string), [])

    enable_ipv6         = optional(bool, false)
    disable_public_ipv4 = optional(bool, false)
    ddos_protection     = optional(bool, false)
    activation_email    = optional(bool, false)
    backups             = optional(string, "disabled")
    backups_schedule = optional(object({
      type = string
      hour = optional(number)
      dow  = optional(number)
      dom  = optional(number)
    }))

    user_data      = optional(string)
    user_scheme    = optional(string)
    ipxe_chain_url = optional(string)

    ssh_key_names       = optional(list(string), [])
    startup_script_name = optional(string)
    firewall_group_name = optional(string)
    vpc_names           = optional(list(string), [])

    reserved_ip_id = optional(string)
  }))
  default = []
}

variable "vpc_id_by_name" {
  description = "Map of VPC name → ID, supplied by the network module"
  type        = map(string)
  default     = {}
}

variable "firewall_group_id_by_name" {
  description = "Map of firewall-group name → ID, supplied by the network module"
  type        = map(string)
  default     = {}
}
