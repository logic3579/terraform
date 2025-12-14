resource "google_compute_router" "this" {
  for_each = { for nat in var.nats : nat.router_name => nat }

  project = var.project_id
  name    = each.value.router_name
  network = each.value.network
  region  = each.value.region

  bgp {
    asn = 64514
  }
}

# External IP for NAT (when using MANUAL_ONLY)
resource "google_compute_address" "nat_ip" {
  for_each = {
    for nat in var.nats :
    nat.name => nat
    if nat.nat_ip_allocate_option == "MANUAL_ONLY"
  }

  project      = var.project_id
  name         = "${each.value.name}-nat-ip"
  region       = each.value.region
  address_type = "EXTERNAL"
}

resource "google_compute_router_nat" "this" {
  for_each = { for nat in var.nats : nat.name => nat }

  project = var.project_id
  name    = each.value.name
  router  = google_compute_router.this[each.value.router_name].name
  region  = each.value.region

  nat_ip_allocate_option             = each.value.nat_ip_allocate_option
  source_subnetwork_ip_ranges_to_nat = each.value.source_subnetwork_ip_ranges_to_nat

  # Attach external IP when using MANUAL_ONLY
  nat_ips = each.value.nat_ip_allocate_option == "MANUAL_ONLY" ? [
    google_compute_address.nat_ip[each.key].self_link
  ] : null

  min_ports_per_vm                    = each.value.min_ports_per_vm
  max_ports_per_vm                    = each.value.max_ports_per_vm
  enable_endpoint_independent_mapping = each.value.enable_endpoint_independent_mapping

  dynamic "log_config" {
    for_each = each.value.log_config != null ? [each.value.log_config] : []
    content {
      enable = log_config.value.enable
      filter = log_config.value.filter
    }
  }
}
