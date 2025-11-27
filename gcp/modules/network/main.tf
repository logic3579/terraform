resource "google_compute_network" "this" {
  project                         = var.project_id
  name                            = var.network_name
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  mtu                             = 1460
  delete_default_routes_on_create = false
}

resource "google_compute_subnetwork" "this" {
  for_each                 = { for s in var.subnets : s.name => s }
  project                  = var.project_id
  name                     = each.value.name
  ip_cidr_range            = each.value.cidr
  region                   = each.value.region
  network                  = google_compute_network.this.id
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
  purpose                  = "PRIVATE"
  role                     = "ACTIVE"
}

resource "google_compute_firewall" "this" {
  for_each = { for f in var.firewalls : f.name => f }

  project = var.project_id
  name    = each.value.name
  network = google_compute_network.this.name

  description = coalesce(each.value.description, "")

  direction = each.value.direction
  priority  = coalesce(each.value.priority, 1000)

  source_ranges      = length(coalesce(each.value.source_ranges, [])) > 0 ? each.value.source_ranges : null
  destination_ranges = length(coalesce(each.value.destination_ranges, [])) > 0 ? each.value.destination_ranges : null

  source_tags             = length(coalesce(each.value.source_tags, [])) > 0 ? each.value.source_tags : null
  target_tags             = length(coalesce(each.value.target_tags, [])) > 0 ? each.value.target_tags : null
  target_service_accounts = length(coalesce(each.value.target_service_accounts, [])) > 0 ? each.value.target_service_accounts : null

  dynamic "allow" {
    for_each = each.value.allow
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }

  disabled = coalesce(each.value.disabled, false)
}
