resource "google_compute_address" "this" {
  for_each = { for vm in var.vm_instances : vm.name => vm if vm.external_ip == true }

  project      = var.project_id
  name         = "${each.value.name}-external-ip"
  region       = each.value.region
  address_type = "EXTERNAL"
}

resource "google_compute_instance" "this" {
  for_each = { for vm in var.vm_instances : vm.name => vm }

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

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt update
    apt install -y ca-certificates curl gnupg lsb-release
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    VERSION_STRING="5:28.5.2-1~ubuntu.24.04~noble"
    apt install -y docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin
    apt-mark hold docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
  EOF

  # Use Compute Engine service account
  service_account {
    email  = each.value.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
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
