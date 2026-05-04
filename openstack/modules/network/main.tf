# ============================================================
# Locals — flatten nested inputs
# ============================================================

locals {
  subnets_flat = flatten([
    for net in var.networks : [
      for sn in coalesce(net.subnets, []) : {
        key          = "${net.name}/${sn.name}"
        network_name = net.name
        subnet       = sn
      }
    ]
  ])

  router_interfaces_flat = flatten([
    for r in var.routers : [
      for iface in coalesce(r.interfaces, []) : {
        key         = "${r.name}/${iface.network_name}/${iface.subnet_name}"
        router_name = r.name
        subnet_key  = "${iface.network_name}/${iface.subnet_name}"
      }
    ]
  ])

  secgroup_rules_flat = flatten([
    for sg in var.security_groups : [
      for i, rule in coalesce(sg.rules, []) : {
        key     = "${sg.name}/${i}"
        sg_name = sg.name
        rule    = rule
      }
    ]
  ])

  # External networks referenced from routers (looked up via data source)
  external_networks = toset([
    for r in var.routers : r.external_network_name
    if r.external_network_name != null
  ])
}

# ============================================================
# External network lookups
# ============================================================

data "openstack_networking_network_v2" "external" {
  for_each = local.external_networks
  name     = each.value
}

# ============================================================
# Networks + Subnets
# ============================================================

resource "openstack_networking_network_v2" "this" {
  for_each = { for n in var.networks : n.name => n }

  name           = each.value.name
  description    = each.value.description
  admin_state_up = each.value.admin_state_up
  shared         = each.value.shared
  external       = each.value.external
  mtu            = each.value.mtu
  tags           = each.value.tags
}

resource "openstack_networking_subnet_v2" "this" {
  for_each = { for s in local.subnets_flat : s.key => s }

  name            = each.value.subnet.name
  network_id      = openstack_networking_network_v2.this[each.value.network_name].id
  cidr            = each.value.subnet.cidr
  ip_version      = each.value.subnet.ip_version
  gateway_ip      = each.value.subnet.gateway_ip
  no_gateway      = each.value.subnet.no_gateway
  enable_dhcp     = each.value.subnet.enable_dhcp
  dns_nameservers = each.value.subnet.dns_nameservers

  dynamic "allocation_pool" {
    for_each = coalesce(each.value.subnet.allocation_pools, [])
    content {
      start = allocation_pool.value.start
      end   = allocation_pool.value.end
    }
  }
}

# ============================================================
# Routers + Interfaces
# ============================================================

resource "openstack_networking_router_v2" "this" {
  for_each = { for r in var.routers : r.name => r }

  name                = each.value.name
  admin_state_up      = each.value.admin_state_up
  distributed         = each.value.distributed
  enable_snat         = each.value.enable_snat
  external_network_id = each.value.external_network_name != null ? data.openstack_networking_network_v2.external[each.value.external_network_name].id : null
}

resource "openstack_networking_router_interface_v2" "this" {
  for_each = { for ri in local.router_interfaces_flat : ri.key => ri }

  router_id = openstack_networking_router_v2.this[each.value.router_name].id
  subnet_id = openstack_networking_subnet_v2.this[each.value.subnet_key].id
}

# ============================================================
# Security Groups + Rules
# ============================================================

resource "openstack_networking_secgroup_v2" "this" {
  for_each = { for sg in var.security_groups : sg.name => sg }

  name        = each.value.name
  description = each.value.description
}

resource "openstack_networking_secgroup_rule_v2" "this" {
  for_each = { for r in local.secgroup_rules_flat : r.key => r }

  security_group_id = openstack_networking_secgroup_v2.this[each.value.sg_name].id
  direction         = each.value.rule.direction
  ethertype         = each.value.rule.ethertype
  protocol          = each.value.rule.protocol
  port_range_min    = each.value.rule.port_range_min
  port_range_max    = each.value.rule.port_range_max
  remote_ip_prefix  = each.value.rule.remote_ip_prefix
  remote_group_id   = each.value.rule.remote_group != null ? openstack_networking_secgroup_v2.this[each.value.rule.remote_group].id : null
  description       = each.value.rule.description
}

# ============================================================
# Floating IPs (allocated from an external pool)
# ============================================================

resource "openstack_networking_floatingip_v2" "this" {
  for_each = { for f in var.floating_ips : f.name => f }

  pool = each.value.pool
}
