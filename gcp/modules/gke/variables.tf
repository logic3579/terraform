variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "gke_clusters" {
  description = "List of GKE cluster configurations (Autopilot or Standard)"
  type = list(object({
    name     = string
    location = string # Region for regional cluster, zone for zonal cluster

    # Cluster type
    enable_autopilot = optional(bool, false)

    # Kubernetes version and release channel
    min_master_version = optional(string)            # e.g. "1.30", null = use release channel default
    release_channel    = optional(string, "REGULAR") # RAPID, REGULAR, STABLE, UNSPECIFIED

    # Networking
    network    = string # VPC network name or self_link
    subnetwork = string # Subnetwork name or self_link

    # VPC-native (alias IP) configuration — required for GKE
    networking_mode = optional(string, "VPC_NATIVE") # VPC_NATIVE or ROUTES
    ip_allocation_policy = optional(object({
      cluster_secondary_range_name  = optional(string) # Existing secondary range name for pods
      services_secondary_range_name = optional(string) # Existing secondary range name for services
      cluster_ipv4_cidr_block       = optional(string) # Auto-create pod range (e.g. "/14")
      services_ipv4_cidr_block      = optional(string) # Auto-create service range (e.g. "/20")
    }))

    # Private cluster configuration
    private_cluster_config = optional(object({
      enable_private_nodes    = bool
      enable_private_endpoint = optional(bool, false) # true = master only reachable from VPC
      master_ipv4_cidr_block  = string                # /28 range for master VPC peering (e.g. "172.16.0.0/28")
    }))

    # Master authorized networks — restrict API server access
    master_authorized_networks = optional(list(object({
      display_name = string
      cidr_block   = string
    })), [])

    # Deletion protection
    deletion_protection = optional(bool, true)

    # Dataplane V2 (eBPF-based, enables NetworkPolicy without Calico)
    datapath_provider = optional(string) # ADVANCED_DATAPATH or LEGACY_DATAPATH, null = provider default

    # DNS configuration
    dns_config = optional(object({
      cluster_dns        = optional(string, "CLOUD_DNS")     # CLOUD_DNS or PLATFORM_DEFAULT
      cluster_dns_scope  = optional(string, "CLUSTER_SCOPE") # CLUSTER_SCOPE or VPC_SCOPE
      cluster_dns_domain = optional(string)                  # Custom domain, null = default
    }))

    # Gateway API support
    gateway_api_config = optional(object({
      channel = string # CHANNEL_STANDARD or CHANNEL_DISABLED
    }))

    # Maintenance window
    maintenance_policy = optional(object({
      start_time = string # RFC3339 UTC, e.g. "2024-01-01T09:00:00Z"
      end_time   = string # RFC3339 UTC, e.g. "2024-01-01T17:00:00Z"
      recurrence = string # RRULE, e.g. "FREQ=WEEKLY;BYDAY=SA,SU"
    }))

    # Logging & monitoring
    logging_enabled_components    = optional(list(string), ["SYSTEM_COMPONENTS", "WORKLOADS"])
    monitoring_enabled_components = optional(list(string), ["SYSTEM_COMPONENTS"])

    # Managed Prometheus
    monitoring_enable_managed_prometheus = optional(bool, true)

    # Addons
    addons_config = optional(object({
      http_load_balancing_disabled        = optional(bool, false)
      horizontal_pod_autoscaling_disabled = optional(bool, false)
      network_policy_enabled              = optional(bool, false) # Standard only; use datapath_provider=ADVANCED_DATAPATH instead for Dataplane V2
      gce_persistent_disk_csi_enabled     = optional(bool, true)
      gcs_fuse_csi_enabled                = optional(bool, false)
      dns_cache_enabled                   = optional(bool, false)
      config_connector_enabled            = optional(bool, false)
      gke_backup_agent_enabled            = optional(bool, false)
      stateful_ha_enabled                 = optional(bool, false)
    }), {})

    # Security
    workload_identity_enabled = optional(bool, true) # Enable Workload Identity Federation
    security_posture_config = optional(object({
      mode               = optional(string, "BASIC") # DISABLED, BASIC, ENTERPRISE
      vulnerability_mode = optional(string, "BASIC") # DISABLED, BASIC, ENTERPRISE
    }))

    # Node pool configuration (Standard mode only, ignored for Autopilot)
    node_pools = optional(list(object({
      name = string

      # Sizing
      machine_type    = optional(string, "e2-medium")
      disk_size_gb    = optional(number, 100)
      disk_type       = optional(string, "pd-balanced")    # pd-standard, pd-balanced, pd-ssd
      image_type      = optional(string, "COS_CONTAINERD") # COS_CONTAINERD, UBUNTU_CONTAINERD
      local_ssd_count = optional(number, 0)

      # Autoscaling
      initial_node_count = optional(number, 1)
      min_node_count     = optional(number, 0)
      max_node_count     = optional(number, 3)
      location_policy    = optional(string, "BALANCED") # BALANCED or ANY

      # Spot / Preemptible
      spot        = optional(bool, false)
      preemptible = optional(bool, false)

      # Auto-repair & auto-upgrade
      auto_repair  = optional(bool, true)
      auto_upgrade = optional(bool, true)

      # Max surge / max unavailable for upgrades
      max_surge       = optional(number, 1)
      max_unavailable = optional(number, 0)

      # Node metadata
      labels = optional(map(string), {})
      tags   = optional(list(string), []) # Network tags

      # Taints
      taints = optional(list(object({
        key    = string
        value  = string
        effect = string # NO_SCHEDULE, PREFER_NO_SCHEDULE, NO_EXECUTE
      })), [])

      # Service account
      service_account = optional(string) # null = default Compute Engine SA
      oauth_scopes = optional(list(string), [
        "https://www.googleapis.com/auth/cloud-platform",
      ])

      # Shielded instance
      enable_secure_boot          = optional(bool, true)
      enable_integrity_monitoring = optional(bool, true)

      # GPU (optional)
      guest_accelerator = optional(object({
        type               = string # e.g. "nvidia-tesla-t4"
        count              = number
        gpu_partition_size = optional(string) # For MIG, e.g. "1g.5gb"
        gpu_sharing_config = optional(object({
          gpu_sharing_strategy       = string # TIME_SHARING or MPS
          max_shared_clients_per_gpu = number
        }))
        gpu_driver_installation_config = optional(object({
          gpu_driver_version = optional(string, "DEFAULT") # DEFAULT, LATEST, DISABLED
        }))
      }))
    })), [])

    # Resource labels for the cluster
    resource_labels = optional(map(string), {})
  }))
  default = []

  validation {
    condition = alltrue([
      for c in var.gke_clusters :
      contains(["RAPID", "REGULAR", "STABLE", "UNSPECIFIED"], c.release_channel)
    ])
    error_message = "Release channel must be one of: RAPID, REGULAR, STABLE, UNSPECIFIED."
  }

  validation {
    condition = alltrue([
      for c in var.gke_clusters :
      contains(["VPC_NATIVE", "ROUTES"], c.networking_mode)
    ])
    error_message = "Networking mode must be either 'VPC_NATIVE' or 'ROUTES'."
  }

  validation {
    condition = alltrue([
      for c in var.gke_clusters :
      c.datapath_provider == null || contains(["ADVANCED_DATAPATH", "LEGACY_DATAPATH"], c.datapath_provider)
    ])
    error_message = "Datapath provider must be 'ADVANCED_DATAPATH' or 'LEGACY_DATAPATH'."
  }

  validation {
    condition = alltrue([
      for c in var.gke_clusters :
      !c.enable_autopilot || length(c.node_pools) == 0
    ])
    error_message = "Autopilot clusters must not define node_pools — node pools are managed automatically."
  }

  validation {
    condition = alltrue([
      for c in var.gke_clusters :
      c.enable_autopilot || length(c.node_pools) > 0
    ])
    error_message = "Standard clusters must define at least one node_pool."
  }

  validation {
    condition = alltrue(flatten([
      for c in var.gke_clusters : [
        for np in c.node_pools :
        contains(["pd-standard", "pd-balanced", "pd-ssd"], np.disk_type)
      ]
    ]))
    error_message = "Node pool disk_type must be one of: pd-standard, pd-balanced, pd-ssd."
  }

  validation {
    condition = alltrue(flatten([
      for c in var.gke_clusters : [
        for np in c.node_pools :
        contains(["COS_CONTAINERD", "UBUNTU_CONTAINERD"], np.image_type)
      ]
    ]))
    error_message = "Node pool image_type must be one of: COS_CONTAINERD, UBUNTU_CONTAINERD."
  }

  validation {
    condition = alltrue(flatten([
      for c in var.gke_clusters : [
        for np in c.node_pools :
        np.min_node_count <= np.max_node_count
      ]
    ]))
    error_message = "Node pool min_node_count must be less than or equal to max_node_count."
  }

  validation {
    condition = alltrue(flatten([
      for c in var.gke_clusters : [
        for np in c.node_pools : [
          for t in np.taints :
          contains(["NO_SCHEDULE", "PREFER_NO_SCHEDULE", "NO_EXECUTE"], t.effect)
        ]
      ]
    ]))
    error_message = "Taint effect must be one of: NO_SCHEDULE, PREFER_NO_SCHEDULE, NO_EXECUTE."
  }

  validation {
    condition = alltrue(flatten([
      for c in var.gke_clusters : [
        for np in c.node_pools :
        contains(["BALANCED", "ANY"], np.location_policy)
      ]
    ]))
    error_message = "Node pool location_policy must be either 'BALANCED' or 'ANY'."
  }

  validation {
    condition = alltrue([
      for c in var.gke_clusters :
      c.private_cluster_config == null || can(cidrhost(c.private_cluster_config.master_ipv4_cidr_block, 0))
    ])
    error_message = "Private cluster master_ipv4_cidr_block must be valid CIDR notation (e.g. 172.16.0.0/28)."
  }

  validation {
    condition = alltrue(flatten([
      for c in var.gke_clusters : [
        for net in c.master_authorized_networks :
        can(cidrhost(net.cidr_block, 0))
      ]
    ]))
    error_message = "Master authorized network cidr_block must be valid CIDR notation."
  }
}
