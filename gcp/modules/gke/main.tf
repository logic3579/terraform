# GKE Cluster module
# Supports both Autopilot and Standard cluster modes.
#
# Autopilot: fully managed node infrastructure, no node_pools needed.
# Standard:  user-managed node pools with fine-grained control.

locals {
  # Build flat map of node pools across all Standard clusters
  node_pools_flat = flatten([
    for cluster in var.gke_clusters : [
      for np in cluster.node_pools : {
        key          = "${cluster.name}/${np.name}"
        cluster_name = cluster.name
        location     = cluster.location
        node_pool    = np
      }
    ] if !cluster.enable_autopilot
  ])
}

resource "google_container_cluster" "this" {
  for_each = { for c in var.gke_clusters : c.name => c }

  provider = google-beta

  project  = var.project_id
  name     = each.value.name
  location = each.value.location

  # Cluster type
  enable_autopilot = each.value.enable_autopilot

  # Version & release channel
  min_master_version = each.value.min_master_version

  release_channel {
    channel = each.value.release_channel
  }

  # Networking
  network    = each.value.network
  subnetwork = each.value.subnetwork

  networking_mode = each.value.networking_mode

  dynamic "ip_allocation_policy" {
    for_each = each.value.ip_allocation_policy != null ? [each.value.ip_allocation_policy] : (
      each.value.networking_mode == "VPC_NATIVE" ? [{}] : []
    )
    content {
      cluster_secondary_range_name  = ip_allocation_policy.value.cluster_secondary_range_name
      services_secondary_range_name = ip_allocation_policy.value.services_secondary_range_name
      cluster_ipv4_cidr_block       = ip_allocation_policy.value.cluster_ipv4_cidr_block
      services_ipv4_cidr_block      = ip_allocation_policy.value.services_ipv4_cidr_block
    }
  }

  # Private cluster
  dynamic "private_cluster_config" {
    for_each = each.value.private_cluster_config != null ? [each.value.private_cluster_config] : []
    content {
      enable_private_nodes    = private_cluster_config.value.enable_private_nodes
      enable_private_endpoint = private_cluster_config.value.enable_private_endpoint
      master_ipv4_cidr_block  = private_cluster_config.value.master_ipv4_cidr_block
    }
  }

  # Master authorized networks
  dynamic "master_authorized_networks_config" {
    for_each = length(each.value.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = each.value.master_authorized_networks
        content {
          display_name = cidr_blocks.value.display_name
          cidr_block   = cidr_blocks.value.cidr_block
        }
      }
    }
  }

  # Dataplane V2
  datapath_provider = each.value.datapath_provider

  # DNS config
  dynamic "dns_config" {
    for_each = each.value.dns_config != null ? [each.value.dns_config] : []
    content {
      cluster_dns        = dns_config.value.cluster_dns
      cluster_dns_scope  = dns_config.value.cluster_dns_scope
      cluster_dns_domain = dns_config.value.cluster_dns_domain
    }
  }

  # Gateway API
  dynamic "gateway_api_config" {
    for_each = each.value.gateway_api_config != null ? [each.value.gateway_api_config] : []
    content {
      channel = gateway_api_config.value.channel
    }
  }

  # Maintenance window
  dynamic "maintenance_policy" {
    for_each = each.value.maintenance_policy != null ? [each.value.maintenance_policy] : []
    content {
      recurring_window {
        start_time = maintenance_policy.value.start_time
        end_time   = maintenance_policy.value.end_time
        recurrence = maintenance_policy.value.recurrence
      }
    }
  }

  # Logging & monitoring
  logging_config {
    enable_components = each.value.logging_enabled_components
  }

  monitoring_config {
    enable_components = each.value.monitoring_enabled_components

    managed_prometheus {
      enabled = each.value.monitoring_enable_managed_prometheus
    }
  }

  # Addons — skip for Autopilot (GKE manages addons automatically)
  dynamic "addons_config" {
    for_each = !each.value.enable_autopilot ? [each.value.addons_config] : []
    content {
      http_load_balancing {
        disabled = addons_config.value.http_load_balancing_disabled
      }
      horizontal_pod_autoscaling {
        disabled = addons_config.value.horizontal_pod_autoscaling_disabled
      }
      network_policy_config {
        disabled = !addons_config.value.network_policy_enabled
      }
      gce_persistent_disk_csi_driver_config {
        enabled = addons_config.value.gce_persistent_disk_csi_enabled
      }
      gcs_fuse_csi_driver_config {
        enabled = addons_config.value.gcs_fuse_csi_enabled
      }
      dns_cache_config {
        enabled = addons_config.value.dns_cache_enabled
      }
      config_connector_config {
        enabled = addons_config.value.config_connector_enabled
      }
      gke_backup_agent_config {
        enabled = addons_config.value.gke_backup_agent_enabled
      }
      stateful_ha_config {
        enabled = addons_config.value.stateful_ha_enabled
      }
    }
  }

  # Workload Identity
  dynamic "workload_identity_config" {
    for_each = each.value.workload_identity_enabled ? [1] : []
    content {
      workload_pool = "${var.project_id}.svc.id.goog"
    }
  }

  # Security posture
  dynamic "security_posture_config" {
    for_each = each.value.security_posture_config != null ? [each.value.security_posture_config] : []
    content {
      mode               = security_posture_config.value.mode
      vulnerability_mode = security_posture_config.value.vulnerability_mode
    }
  }

  # Deletion protection
  deletion_protection = each.value.deletion_protection

  # For Standard clusters: remove default node pool, we manage our own
  # For Autopilot: this is ignored
  remove_default_node_pool = each.value.enable_autopilot ? null : true
  initial_node_count       = each.value.enable_autopilot ? null : 1

  # Labels
  resource_labels = merge(var.labels, each.value.resource_labels)

  lifecycle {
    ignore_changes = [
      # Node pool changes managed by google_container_node_pool resources
      node_pool,
      initial_node_count,
    ]
  }
}

# Node pools for Standard clusters
resource "google_container_node_pool" "this" {
  for_each = { for np in local.node_pools_flat : np.key => np }

  provider = google-beta

  project  = var.project_id
  cluster  = google_container_cluster.this[each.value.cluster_name].name
  location = each.value.location
  name     = each.value.node_pool.name

  # Autoscaling
  initial_node_count = each.value.node_pool.initial_node_count

  autoscaling {
    min_node_count  = each.value.node_pool.min_node_count
    max_node_count  = each.value.node_pool.max_node_count
    location_policy = each.value.node_pool.location_policy
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = each.value.node_pool.max_surge
    max_unavailable = each.value.node_pool.max_unavailable
  }

  management {
    auto_repair  = each.value.node_pool.auto_repair
    auto_upgrade = each.value.node_pool.auto_upgrade
  }

  node_config {
    machine_type    = each.value.node_pool.machine_type
    disk_size_gb    = each.value.node_pool.disk_size_gb
    disk_type       = each.value.node_pool.disk_type
    image_type      = each.value.node_pool.image_type
    local_ssd_count = each.value.node_pool.local_ssd_count

    spot        = each.value.node_pool.spot
    preemptible = each.value.node_pool.preemptible

    labels = each.value.node_pool.labels
    tags   = each.value.node_pool.tags

    service_account = each.value.node_pool.service_account
    oauth_scopes    = each.value.node_pool.oauth_scopes

    # Taints
    dynamic "taint" {
      for_each = each.value.node_pool.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    # GPU
    dynamic "guest_accelerator" {
      for_each = each.value.node_pool.guest_accelerator != null ? [each.value.node_pool.guest_accelerator] : []
      content {
        type               = guest_accelerator.value.type
        count              = guest_accelerator.value.count
        gpu_partition_size = guest_accelerator.value.gpu_partition_size

        dynamic "gpu_sharing_config" {
          for_each = guest_accelerator.value.gpu_sharing_config != null ? [guest_accelerator.value.gpu_sharing_config] : []
          content {
            gpu_sharing_strategy       = gpu_sharing_config.value.gpu_sharing_strategy
            max_shared_clients_per_gpu = gpu_sharing_config.value.max_shared_clients_per_gpu
          }
        }

        dynamic "gpu_driver_installation_config" {
          for_each = guest_accelerator.value.gpu_driver_installation_config != null ? [guest_accelerator.value.gpu_driver_installation_config] : []
          content {
            gpu_driver_version = gpu_driver_installation_config.value.gpu_driver_version
          }
        }
      }
    }

    # Shielded instance
    shielded_instance_config {
      enable_secure_boot          = each.value.node_pool.enable_secure_boot
      enable_integrity_monitoring = each.value.node_pool.enable_integrity_monitoring
    }

    # Workload Identity metadata
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  lifecycle {
    ignore_changes = [
      # Allow external scaling (e.g. cluster autoscaler)
      initial_node_count,
    ]
  }
}
