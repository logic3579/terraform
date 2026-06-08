output "ssh_keys" {
  description = "SSH keys keyed by name"
  value       = vultr_ssh_key.this
}

output "startup_scripts" {
  description = "Startup scripts keyed by name"
  value = {
    for k, v in vultr_startup_script.this : k => {
      id            = v.id
      name          = v.name
      type          = v.type
      date_created  = v.date_created
      date_modified = v.date_modified
    }
  }
}

output "instances" {
  description = "Instances keyed by name (sensitive fields like default_password omitted)"
  value = {
    for k, v in vultr_instance.this : k => {
      id           = v.id
      region       = v.region
      plan         = v.plan
      hostname     = v.hostname
      label        = v.label
      main_ip      = v.main_ip
      internal_ip  = v.internal_ip
      v6_main_ip   = v.v6_main_ip
      status       = v.status
      power_status = v.power_status
      tags         = v.tags
      os           = v.os
      ram          = v.ram
      vcpu_count   = v.vcpu_count
    }
  }
}
