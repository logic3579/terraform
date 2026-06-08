variable "vpcs" {
  description = "VPCs to create (vultr_vpc — the v1 resource; vultr_vpc2 is deprecated upstream)"
  type = list(object({
    name           = string
    region         = string
    description    = optional(string)
    v4_subnet      = optional(string) # auto-generated if omitted
    v4_subnet_mask = optional(number) # bits in the netmask, e.g. 24
  }))
  default = []
}

variable "firewall_groups" {
  description = "Firewall groups and their rules"
  type = list(object({
    name        = string # local key only — Vultr firewall groups don't have a name field, only `description`
    description = optional(string)

    rules = optional(list(object({
      protocol    = string                 # icmp | tcp | udp | gre | esp | ah  (lowercase)
      ip_type     = optional(string, "v4") # v4 | v6
      subnet      = string                 # IP address, e.g. 0.0.0.0
      subnet_size = number                 # bits, e.g. 0 for "any"
      port        = optional(string)       # tcp/udp only; single port or "from:to"
      notes       = optional(string)
      source      = optional(string) # "" | cloudflare
    })), [])
  }))
  default = []

  validation {
    condition = alltrue([
      for g in var.firewall_groups : alltrue([
        for r in coalesce(g.rules, []) : contains(["icmp", "tcp", "udp", "gre", "esp", "ah"], r.protocol)
      ])
    ])
    error_message = "Firewall rule protocol must be one of: icmp, tcp, udp, gre, esp, ah (lowercase)."
  }

  validation {
    condition = alltrue([
      for g in var.firewall_groups : alltrue([
        for r in coalesce(g.rules, []) : contains(["v4", "v6"], r.ip_type)
      ])
    ])
    error_message = "Firewall rule ip_type must be 'v4' or 'v6'."
  }
}

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
    script = string                   # base64-encoded content
    type   = optional(string, "boot") # boot | pxe
  }))
  default = []

  validation {
    condition     = alltrue([for s in var.startup_scripts : contains(["boot", "pxe"], s.type)])
    error_message = "Startup script type must be 'boot' or 'pxe'."
  }
}

variable "instances" {
  description = "Vultr compute instances"
  type = list(object({
    name   = string
    region = string
    plan   = string

    # exactly one image source is required by Vultr's API; module passes all
    # supplied fields through and lets the provider enforce that constraint.
    os_id       = optional(number)
    iso_id      = optional(string)
    app_id      = optional(number)
    image_id    = optional(string) # marketplace app
    snapshot_id = optional(string)

    label    = optional(string)
    hostname = optional(string)
    tags     = optional(list(string), [])

    enable_ipv6         = optional(bool, false)
    disable_public_ipv4 = optional(bool, false)
    ddos_protection     = optional(bool, false)
    activation_email    = optional(bool, false)
    backups             = optional(string, "disabled") # enabled | disabled
    backups_schedule = optional(object({
      type = string # daily | weekly | monthly | daily_alt_even | daily_alt_odd
      hour = optional(number)
      dow  = optional(number)
      dom  = optional(number)
    }))

    user_data      = optional(string) # plain text; provider handles base64 encoding
    user_scheme    = optional(string) # root | limited
    ipxe_chain_url = optional(string)

    # cross-module references resolved by name in this module
    ssh_key_names       = optional(list(string), [])
    startup_script_name = optional(string)
    firewall_group_name = optional(string)
    vpc_names           = optional(list(string), [])

    reserved_ip_id = optional(string)
  }))
  default = []

  validation {
    condition     = alltrue([for i in var.instances : contains(["enabled", "disabled"], i.backups)])
    error_message = "instance.backups must be 'enabled' or 'disabled'."
  }
}
