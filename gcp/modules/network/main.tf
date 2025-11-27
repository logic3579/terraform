resource "google_compute_network" "this" {
  project                         = var.project_id
  name                            = var.network_name
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  mtu                             = 1460
  delete_default_routes_on_create = false
  # labels                          = var.labels
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
  # labels                   = var.labels
}
