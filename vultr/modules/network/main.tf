# ============================================================
# Locals — flatten nested firewall rules
# ============================================================

locals {
  firewall_rules_flat = flatten([
    for g in var.firewall_groups : [
      for i, r in coalesce(g.rules, []) : {
        key        = "${g.name}/${i}"
        group_name = g.name
        rule       = r
      }
    ]
  ])
}

# ============================================================
# VPCs
# ============================================================

# Uses vultr_vpc (v1). vultr_vpc2 is marked deprecated by upstream — see
# website/docs/r/vpc2.html.markdown: "** Deprecated: Use vultr_vpc instead **".
resource "vultr_vpc" "this" {
  for_each = { for v in var.vpcs : v.name => v }

  region         = each.value.region
  description    = each.value.description
  v4_subnet      = each.value.v4_subnet
  v4_subnet_mask = each.value.v4_subnet_mask
}

# ============================================================
# Firewall groups + rules
# ============================================================

resource "vultr_firewall_group" "this" {
  for_each = { for g in var.firewall_groups : g.name => g }

  description = each.value.description
}

resource "vultr_firewall_rule" "this" {
  for_each = { for r in local.firewall_rules_flat : r.key => r }

  firewall_group_id = vultr_firewall_group.this[each.value.group_name].id
  protocol          = each.value.rule.protocol
  ip_type           = each.value.rule.ip_type
  subnet            = each.value.rule.subnet
  subnet_size       = each.value.rule.subnet_size
  port              = each.value.rule.port
  notes             = each.value.rule.notes
  source            = each.value.rule.source
}
