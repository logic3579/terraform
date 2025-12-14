# Get current project information for default service account
data "google_project" "current" {
  project_id = var.project_id
}

locals {
  # Default Compute Engine service account
  default_compute_sa = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_compute_address" "this" {
  for_each = { for vm in var.instances : vm.name => vm if vm.external_ip == true }

  project      = var.project_id
  name         = "${each.value.name}-external-ip"
  region       = each.value.region
  address_type = "EXTERNAL"
}

resource "google_compute_instance" "this" {
  for_each = { for vm in var.instances : vm.name => vm }

  project      = var.project_id
  name         = each.value.name
  machine_type = each.value.machine_type
  zone         = each.value.zone
  tags         = each.value.network_tags

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "projects/${each.value.image_project}/global/images/family/${each.value.image_family}"
      size  = each.value.disk_size
      type  = each.value.disk_type
    }
  }

  network_interface {
    network    = each.value.network
    subnetwork = each.value.subnetwork

    dynamic "access_config" {
      for_each = each.value.external_ip ? [1] : []
      content {
        nat_ip = google_compute_address.this[each.key].address
      }
    }
  }

  # Startup script configuration - supports inline script or external file
  metadata_startup_script = each.value.startup_script != null ? each.value.startup_script : (
    each.value.startup_script_file != null ? file(each.value.startup_script_file) : null
  )

  metadata = each.value.metadata

  # Service account configuration
  # Uses default Compute Engine SA if not specified
  service_account {
    email  = coalesce(each.value.service_account_email, local.default_compute_sa)
    scopes = coalesce(each.value.service_account_scopes, ["https://www.googleapis.com/auth/cloud-platform"])
  }

  scheduling {
    preemptible       = false
    automatic_restart = true
  }

  lifecycle {
    prevent_destroy       = false
    create_before_destroy = true
    ignore_changes = [
      metadata,
      metadata_startup_script,
      metadata["ssh-keys"],
    ]
  }
}

resource "google_compute_instance_group" "this" {
  for_each = { for ig in var.instance_groups : ig.name => ig }

  project     = var.project_id
  name        = each.value.name
  description = each.value.description
  zone        = each.value.zone

  instances = [
    for instance_name in each.value.instances :
    google_compute_instance.this[instance_name].self_link
  ]

  dynamic "named_port" {
    for_each = coalesce(each.value.named_ports, [])
    content {
      name = named_port.value.name
      port = named_port.value.port
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
