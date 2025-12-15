# Flatten subnets and firewalls with network reference
locals {
  subnets_flat = flatten([
    for network in var.networks : [
      for subnet in coalesce(network.subnets, []) : {
        key          = "${network.name}/${subnet.name}"
        network_name = network.name
        subnet       = subnet
      }
    ]
  ])

  firewalls_flat = flatten([
    for network in var.networks : [
      for fw in coalesce(network.firewalls, []) : {
        key          = "${network.name}/${fw.name}"
        network_name = network.name
        firewall     = fw
      }
    ]
  ])

  # Helper function to convert empty list to null
  # This avoids repeating the length(coalesce(...)) > 0 pattern
  firewall_attrs = {
    for f in local.firewalls_flat : f.key => {
      source_ranges           = length(coalesce(f.firewall.source_ranges, [])) > 0 ? f.firewall.source_ranges : null
      destination_ranges      = length(coalesce(f.firewall.destination_ranges, [])) > 0 ? f.firewall.destination_ranges : null
      source_tags             = length(coalesce(f.firewall.source_tags, [])) > 0 ? f.firewall.source_tags : null
      target_tags             = length(coalesce(f.firewall.target_tags, [])) > 0 ? f.firewall.target_tags : null
      target_service_accounts = length(coalesce(f.firewall.target_service_accounts, [])) > 0 ? f.firewall.target_service_accounts : null
    }
  }
}

# Create multiple VPCs
resource "google_compute_network" "this" {
  for_each = { for n in var.networks : n.name => n }

  project                         = var.project_id
  name                            = each.value.name
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  mtu                             = 1460
  delete_default_routes_on_create = false
}

# Create subnets with network reference
resource "google_compute_subnetwork" "this" {
  for_each = { for s in local.subnets_flat : s.key => s }

  project                  = var.project_id
  name                     = each.value.subnet.name
  ip_cidr_range            = each.value.subnet.cidr
  region                   = each.value.subnet.region
  network                  = google_compute_network.this[each.value.network_name].id
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
  purpose                  = "PRIVATE"

  lifecycle {
    ignore_changes = [
      description,
      secondary_ip_range,
      role,
    ]
  }
}

# Create firewall rules with network reference
resource "google_compute_firewall" "this" {
  for_each = { for f in local.firewalls_flat : f.key => f }

  project     = var.project_id
  name        = each.value.firewall.name
  network     = google_compute_network.this[each.value.network_name].name
  description = coalesce(each.value.firewall.description, "")
  direction   = each.value.firewall.direction
  priority    = coalesce(each.value.firewall.priority, 1000)

  # Use pre-computed attributes from locals to avoid repetitive logic
  source_ranges           = local.firewall_attrs[each.key].source_ranges
  destination_ranges      = local.firewall_attrs[each.key].destination_ranges
  source_tags             = local.firewall_attrs[each.key].source_tags
  target_tags             = local.firewall_attrs[each.key].target_tags
  target_service_accounts = local.firewall_attrs[each.key].target_service_accounts

  dynamic "allow" {
    for_each = each.value.firewall.allow
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }

  disabled = coalesce(each.value.firewall.disabled, false)
}
