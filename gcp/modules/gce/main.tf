locals {
  default_labels = merge(
    var.default_labels,
    {
      env     = var.env
      project = var.project_id
      managed = "terraform"
    },
  )
}

resource "google_compute_instance" "this" {
  for_each = { for i in var.instances : i.name => i }

  project      = var.project_id
  name         = each.value.name
  machine_type = each.value.machine_type
  zone         = coalesce(each.value.zone, var.zone)

  tags = coalesce(each.value.tags, [])

  labels = merge(
    local.default_labels,
    coalesce(each.value.labels, {}),
  )

  boot_disk {
    initialize_params {
      image = var.boot_disk_image
    }
  }

  network_interface {
    # If subnetwork_self_link is provided, attach to that; otherwise use default network
    subnetwork = var.subnetwork_self_link
  }

  service_account {
    email  = coalesce(each.value.service_account_email, var.default_service_account_email)
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = coalesce(each.value.metadata, {})
}

resource "google_compute_instance_group" "this" {
  for_each = { for g in var.instance_groups : g.name => g }

  project = var.project_id
  name    = gpc_tf_name_prefix(var.prefix, gpc_tf_env_suffix(var.env, g.name))
  zone    = each.value.zone
  named_port {
    name = "http"
    port = 80
  }

  instances = [
    for name, inst in google_compute_instance.this : inst.self_link if contains(each.value.instances, name)
  ]
}

# Simple helper functions implemented as local expressions
# Terraform doesn't support user-defined functions; we emulate naming helpers via locals below.
