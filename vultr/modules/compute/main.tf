resource "vultr_ssh_key" "this" {
  for_each = { for k in var.ssh_keys : k.name => k }

  name    = each.value.name
  ssh_key = each.value.ssh_key
}

resource "vultr_startup_script" "this" {
  for_each = { for s in var.startup_scripts : s.name => s }

  name   = each.value.name
  script = each.value.script
  type   = each.value.type
}

resource "vultr_instance" "this" {
  for_each = { for i in var.instances : i.name => i }

  region = each.value.region
  plan   = each.value.plan

  os_id       = each.value.os_id
  iso_id      = each.value.iso_id
  app_id      = each.value.app_id
  image_id    = each.value.image_id
  snapshot_id = each.value.snapshot_id

  label    = each.value.label
  hostname = each.value.hostname
  tags     = each.value.tags

  enable_ipv6         = each.value.enable_ipv6
  disable_public_ipv4 = each.value.disable_public_ipv4
  ddos_protection     = each.value.ddos_protection
  activation_email    = each.value.activation_email
  backups             = each.value.backups

  dynamic "backups_schedule" {
    for_each = each.value.backups_schedule != null ? [each.value.backups_schedule] : []
    content {
      type = backups_schedule.value.type
      hour = backups_schedule.value.hour
      dow  = backups_schedule.value.dow
      dom  = backups_schedule.value.dom
    }
  }

  user_data      = each.value.user_data
  user_scheme    = each.value.user_scheme
  ipxe_chain_url = each.value.ipxe_chain_url

  ssh_key_ids = [for n in each.value.ssh_key_names : vultr_ssh_key.this[n].id]
  script_id   = each.value.startup_script_name != null ? vultr_startup_script.this[each.value.startup_script_name].id : null

  firewall_group_id = each.value.firewall_group_name != null ? var.firewall_group_id_by_name[each.value.firewall_group_name] : null

  vpc_ids = [for n in each.value.vpc_names : var.vpc_id_by_name[n]]

  reserved_ip_id = each.value.reserved_ip_id
}
