# Get current project information for default service account
data "google_project" "current" {
  project_id = var.project_id
}

locals {
  # Default Compute Engine service account
  default_compute_sa = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"

  # Cloud-init configuration processing
  cloud_init_configs = {
    for vm in var.instances : vm.name => {
      enabled = vm.cloud_init != null && vm.cloud_init.enabled
      user_data = vm.cloud_init != null && vm.cloud_init.enabled ? templatefile(
        "${path.module}/../../templates/cloud-init.yaml.tpl",
        {
          hostname       = coalesce(vm.cloud_init.hostname, "")
          install_docker = coalesce(vm.cloud_init.install_docker, true)
          packages = coalesce(vm.cloud_init.packages, [
            "htop",
            "net-tools",
            "iputils-ping"
          ])
          additional_config = try(vm.cloud_init.additional_config, "")
        }
      ) : ""
    }
  }
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
  labels       = merge(var.labels, each.value.labels)

  deletion_protection       = each.value.deletion_protection
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

  # Metadata configuration - supports cloud-init
  metadata = merge(
    coalesce(each.value.metadata, {}),
    local.cloud_init_configs[each.key].enabled ? {
      user-data = local.cloud_init_configs[each.key].user_data
    } : {}
  )

  # Service account configuration
  # Uses default Compute Engine SA if not specified
  service_account {
    email  = coalesce(each.value.service_account_email, local.default_compute_sa)
    scopes = each.value.service_account_scopes
  }

  scheduling {
    preemptible       = each.value.preemptible
    automatic_restart = each.value.preemptible ? false : true
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    prevent_destroy       = false
    create_before_destroy = true
    ignore_changes = [
      metadata,
      metadata["ssh-keys"],
      metadata_startup_script,
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
