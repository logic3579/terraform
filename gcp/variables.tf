variable "env" {
  description = "Environment name (e.g. dev, test, devtest, uat, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "devtest", "uat", "prod"], var.env)
    error_message = "Environment must be one of: dev, test, devtest, uat, prod."
  }
}

variable "labels" {
  description = "Labels applied to all resources in this root module"
  type        = map(string)
  default     = {}
}

variable "project_id" {
  description = "GCP project ID"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with a lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "GCP region"
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "Region must be a valid GCP region format (e.g., us-central1, asia-southeast1)."
  }
}

variable "zone" {
  description = "Default GCE zone for compute resources"
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+-[a-z]$", var.zone))
    error_message = "Zone must be a valid GCP zone format (e.g., us-central1-a, asia-southeast1-b)."
  }
}

variable "networks" {
  description = "List of VPC network configurations with their subnets and firewalls"
  type = list(object({
    name = string
    subnets = optional(list(object({
      name   = string
      cidr   = string
      region = string
    })), [])
    firewalls = optional(list(object({
      name                    = string
      description             = optional(string)
      direction               = string
      priority                = optional(number)
      source_ranges           = optional(list(string))
      destination_ranges      = optional(list(string))
      source_tags             = optional(list(string))
      target_tags             = optional(list(string))
      target_service_accounts = optional(list(string))
      allow = list(object({
        protocol = string
        ports    = optional(list(string))
      }))
      disabled = optional(bool)
    })), [])
  }))
  default = []

  validation {
    condition = alltrue([
      for network in var.networks :
      can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", network.name)) || can(regex("^[a-z]$", network.name))
    ])
    error_message = "Network name must be 1-63 characters, start with a lowercase letter, end with a letter or number, and contain only lowercase letters, numbers, and hyphens."
  }

  validation {
    condition = alltrue(flatten([
      for network in var.networks : [
        for subnet in coalesce(network.subnets, []) :
        can(cidrhost(subnet.cidr, 0))
      ]
    ]))
    error_message = "All subnet CIDR blocks must be valid CIDR notation (e.g., 10.0.0.0/24)."
  }

  validation {
    condition = alltrue(flatten([
      for network in var.networks : [
        for fw in coalesce(network.firewalls, []) :
        contains(["INGRESS", "EGRESS"], fw.direction)
      ]
    ]))
    error_message = "Firewall direction must be either 'INGRESS' or 'EGRESS'."
  }
}

variable "nats" {
  description = "List of NAT configurations"
  type = list(object({
    name                               = string
    router_name                        = string
    network                            = string
    region                             = string
    source_subnetwork_ip_ranges_to_nat = optional(string, "ALL_SUBNETWORKS_ALL_IP_RANGES")
    nat_ip_allocate_option             = optional(string, "AUTO_ONLY")

    # Dynamic Port Allocation (DPA) configuration
    enable_dynamic_port_allocation = optional(bool, false)

    # Port allocation settings
    min_ports_per_vm = optional(number, 64)
    max_ports_per_vm = optional(number) # Only used when DPA is enabled

    enable_endpoint_independent_mapping = optional(bool, false)
    log_config = optional(object({
      enable = bool
      filter = string
    }))
  }))
  default = []

  validation {
    condition = alltrue([
      for nat in var.nats :
      contains(["AUTO_ONLY", "MANUAL_ONLY"], nat.nat_ip_allocate_option)
    ])
    error_message = "NAT IP allocate option must be either 'AUTO_ONLY' or 'MANUAL_ONLY'."
  }

  validation {
    condition = alltrue([
      for nat in var.nats :
      contains([
        "ALL_SUBNETWORKS_ALL_IP_RANGES",
        "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES",
        "LIST_OF_SUBNETWORKS"
      ], nat.source_subnetwork_ip_ranges_to_nat)
    ])
    error_message = "Source subnetwork IP ranges must be one of: ALL_SUBNETWORKS_ALL_IP_RANGES, ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES, LIST_OF_SUBNETWORKS."
  }

  # Validation: DPA and Endpoint-Independent Mapping are mutually exclusive
  validation {
    condition = alltrue([
      for nat in var.nats :
      !(nat.enable_dynamic_port_allocation == true && nat.enable_endpoint_independent_mapping == true)
    ])
    error_message = "enable_dynamic_port_allocation and enable_endpoint_independent_mapping cannot both be true. They are mutually exclusive."
  }

  # Validation: min_ports_per_vm range check
  validation {
    condition = alltrue([
      for nat in var.nats :
      nat.enable_dynamic_port_allocation ?
      (nat.min_ports_per_vm >= 32 && nat.min_ports_per_vm <= 32768) :
      (nat.min_ports_per_vm >= 64 && nat.min_ports_per_vm <= 65536)
    ])
    error_message = "min_ports_per_vm must be 64-65536 for static mode, or 32-32768 for dynamic port allocation."
  }

  # Validation: When DPA is enabled, min_ports_per_vm must be power of 2
  validation {
    condition = alltrue([
      for nat in var.nats :
      nat.enable_dynamic_port_allocation != true ||
      can(regex("^(32|64|128|256|512|1024|2048|4096|8192|16384|32768)$", tostring(nat.min_ports_per_vm)))
    ])
    error_message = "When enable_dynamic_port_allocation is true, min_ports_per_vm must be a power of 2 (32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768)."
  }
}

variable "service_accounts" {
  description = "Service accounts to create at project level"
  type = list(object({
    account_id   = string
    display_name = string
    description  = optional(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for sa in var.service_accounts :
      can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", sa.account_id))
    ])
    error_message = "Service account ID must be 6-30 characters, start with a lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "iam_bindings" {
  description = "Project-level IAM bindings per service account"
  type = list(object({
    service_account_email = string
    roles                 = list(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for binding in var.iam_bindings :
      can(regex("^[a-z][a-z0-9-]+@[a-z][a-z0-9-]+\\.iam\\.gserviceaccount\\.com$", binding.service_account_email))
    ])
    error_message = "Service account email must be a valid GCP service account email format."
  }

  validation {
    condition = alltrue([
      for binding in var.iam_bindings :
      alltrue([
        for role in binding.roles :
        can(regex("^roles/", role)) || can(regex("^projects/", role)) || can(regex("^organizations/", role))
      ])
    ])
    error_message = "IAM roles must start with 'roles/', 'projects/', or 'organizations/'."
  }
}

variable "workload_identity_bindings" {
  description = "Workload Identity bindings to allow Kubernetes Service Accounts to impersonate Google Service Accounts"
  type = list(object({
    service_account_id = string # The service account ID (not email) to bind
    namespace          = string # Kubernetes namespace
    ksa_name           = string # Kubernetes Service Account name
    wi_pool_project_id = string # WI pool project ID (project where GKE cluster resides)
  }))
  default = []

  validation {
    condition = alltrue([
      for wi in var.workload_identity_bindings :
      can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", wi.service_account_id))
    ])
    error_message = "Service account ID must be 6-30 characters, start with a lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }

  validation {
    condition = alltrue([
      for wi in var.workload_identity_bindings :
      can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", wi.namespace))
    ])
    error_message = "Kubernetes namespace must be a valid DNS label (lowercase, alphanumeric, hyphens, max 63 chars)."
  }

  validation {
    condition = alltrue([
      for wi in var.workload_identity_bindings :
      can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", wi.ksa_name))
    ])
    error_message = "Kubernetes Service Account name must be a valid DNS label (lowercase, alphanumeric, hyphens, max 63 chars)."
  }

  validation {
    condition = alltrue([
      for wi in var.workload_identity_bindings :
      can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", wi.wi_pool_project_id))
    ])
    error_message = "WI pool project ID must be a valid GCP project ID format."
  }
}

variable "buckets" {
  description = "List of GCS buckets to create"
  type = list(object({
    name                     = string
    location                 = string
    storage_class            = optional(string)
    public_access_prevention = optional(string)
    versioning_enabled       = optional(bool)
    labels                   = optional(map(string))
    lifecycle_rules = optional(list(object({
      action = object({
        type          = string
        storage_class = optional(string)
      })
      condition = object({
        age        = optional(number)
        with_state = optional(string)
      })
    })))
  }))
  default = []

  validation {
    condition = alltrue([
      for bucket in var.buckets :
      can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", bucket.name)) || can(regex("^[a-z0-9]$", bucket.name))
    ])
    error_message = "Bucket name must be 3-63 characters, start and end with a letter or number, and contain only lowercase letters, numbers, hyphens, underscores, and dots."
  }

  validation {
    condition = alltrue([
      for bucket in var.buckets :
      bucket.storage_class == null || contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], bucket.storage_class)
    ])
    error_message = "Storage class must be one of: STANDARD, NEARLINE, COLDLINE, ARCHIVE."
  }

  validation {
    condition = alltrue([
      for bucket in var.buckets :
      bucket.public_access_prevention == null || contains(["enforced", "inherited"], bucket.public_access_prevention)
    ])
    error_message = "Public access prevention must be either 'enforced' or 'inherited'."
  }
}

variable "instances" {
  description = "List of VM instances to create"
  type = list(object({
    name          = string
    machine_type  = string
    region        = string
    zone          = string
    network_tags  = list(string)
    external_ip   = optional(bool, false)
    image_family  = string
    image_project = string
    disk_size     = number
    disk_type     = string
    network       = string
    subnetwork    = string

    # Service account configuration
    service_account_email = optional(string) # null = use default Compute Engine SA
    service_account_scopes = optional(list(string), [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append",
    ])

    # Preemptible VM configuration
    preemptible = optional(bool, false)

    # Deletion protection (prevents accidental deletion via API/Console)
    deletion_protection = optional(bool, false)

    # Metadata and labels
    metadata = optional(map(string), {})
    labels   = optional(map(string), {})

    # Cloud-init configuration
    cloud_init = optional(object({
      enabled        = bool
      hostname       = optional(string)
      install_docker = optional(bool, true)
      packages = optional(list(string), [
        "htop",
        "net-tools",
        "iputils-ping"
      ])
      additional_config = optional(string, "")
    }))

    # Additional disks to create and/or attach
    additional_disks = optional(list(object({
      name     = string
      size     = optional(number, 20)            # GB, ignored when existing=true
      type     = optional(string, "pd-standard") # ignored when existing=true
      zone     = optional(string)                # defaults to VM zone
      mode     = optional(string, "READ_WRITE")  # READ_WRITE or READ_ONLY
      existing = optional(bool, false)           # true=lookup existing disk, false=create new
      labels   = optional(map(string), {})       # ignored when existing=true
    })), [])
  }))
  default = []

  validation {
    condition = alltrue([
      for vm in var.instances :
      contains(["pd-standard", "pd-balanced", "pd-ssd", "pd-extreme"], vm.disk_type)
    ])
    error_message = "Disk type must be one of: pd-standard, pd-balanced, pd-ssd, pd-extreme."
  }

  validation {
    condition = alltrue([
      for vm in var.instances :
      vm.disk_size >= 10 && vm.disk_size <= 65536
    ])
    error_message = "Disk size must be between 10 and 65536 GB."
  }

  # Validation: Hostname format validation
  validation {
    condition = alltrue([
      for vm in var.instances :
      vm.cloud_init == null || !vm.cloud_init.enabled ||
      (vm.cloud_init.hostname == null ||
      can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$|^[a-z0-9]$", vm.cloud_init.hostname)))
    ])
    error_message = "cloud_init.hostname must be a valid hostname format (lowercase letters, numbers, hyphens, 1-63 chars)."
  }

  # Validation: Package name format validation
  validation {
    condition = alltrue(flatten([
      for vm in var.instances : [
        for pkg in coalesce(vm.cloud_init != null ? vm.cloud_init.packages : null, []) :
        can(regex("^[a-z0-9][a-z0-9+.-]*$", pkg))
      ] if vm.cloud_init != null && vm.cloud_init.enabled
    ]))
    error_message = "Package names must follow valid package naming conventions."
  }

  validation {
    condition = alltrue([
      for vm in var.instances :
      can(regex("^[a-z]+-[a-z]+[0-9]+-[a-z]$", vm.zone))
    ])
    error_message = "Instance zone must be a valid GCP zone format (e.g., us-central1-a)."
  }

  # Validation: Additional disk type
  validation {
    condition = alltrue(flatten([
      for vm in var.instances : [
        for disk in vm.additional_disks :
        contains(["pd-standard", "pd-balanced", "pd-ssd", "pd-extreme"], disk.type)
      ]
    ]))
    error_message = "Additional disk type must be one of: pd-standard, pd-balanced, pd-ssd, pd-extreme."
  }

  # Validation: Additional disk mode
  validation {
    condition = alltrue(flatten([
      for vm in var.instances : [
        for disk in vm.additional_disks :
        contains(["READ_WRITE", "READ_ONLY"], disk.mode)
      ]
    ]))
    error_message = "Additional disk mode must be one of: READ_WRITE, READ_ONLY."
  }

  # Validation: Additional disk size (only for new disks)
  validation {
    condition = alltrue(flatten([
      for vm in var.instances : [
        for disk in vm.additional_disks :
        disk.existing || (disk.size >= 10 && disk.size <= 65536)
      ]
    ]))
    error_message = "Additional disk size must be between 10 and 65536 GB."
  }
}

variable "instance_groups" {
  description = "List of instance groups to create"
  type = list(object({
    name        = string
    description = optional(string)
    zone        = string
    instances   = list(string)
    named_ports = optional(list(object({
      name = string
      port = number
    })))
  }))
  default = []
}

variable "load_balancers" {
  description = "List of load balancer configurations"
  type = list(object({
    name                = string
    description         = optional(string)
    global_address_name = optional(string) # Name of the global address to use (allows sharing IP between LBs)

    # Port configuration
    http_port  = optional(number, 80)
    https_port = optional(number, 443)

    # Health check configuration (TCP, HTTP, HTTPS)
    health_check = object({
      name                = string
      type                = optional(string, "TCP")
      check_interval_sec  = optional(number, 5)
      timeout_sec         = optional(number, 5)
      healthy_threshold   = optional(number, 2)
      unhealthy_threshold = optional(number, 2)
      port                = optional(number, 80)
      # HTTP/HTTPS specific
      request_path = optional(string, "/")
      host         = optional(string)
    })

    # Backend service configuration
    backend_service = object({
      name                  = string
      protocol              = optional(string, "HTTP")
      port_name             = optional(string, "http")
      timeout_sec           = optional(number, 30)
      enable_cdn            = optional(bool, false)
      session_affinity      = optional(string, "NONE")
      balancing_mode        = optional(string, "UTILIZATION") # UTILIZATION or RATE
      max_utilization       = optional(number, 0.8)
      max_rate_per_instance = optional(number)
      instance_groups       = list(string)     # List of instance group self_links
      security_policy       = optional(string) # Cloud Armor security policy (null to disable)
      enable_logging        = optional(bool, false)
      log_sample_rate       = optional(number, 1.0)
    })

    # SSL configuration (optional, uses GCP-managed certificates)
    ssl_config = optional(object({
      enabled             = bool
      certificate_domains = list(string) # Domains for GCP-managed SSL certificate
    }))
  }))
  default = []

  validation {
    condition = alltrue([
      for lb in var.load_balancers :
      contains(["UTILIZATION", "RATE"], lb.backend_service.balancing_mode)
    ])
    error_message = "Backend service balancing_mode must be either 'UTILIZATION' or 'RATE'."
  }

  validation {
    condition = alltrue([
      for lb in var.load_balancers :
      contains(["HTTP", "HTTPS", "HTTP2", "TCP", "SSL"], lb.backend_service.protocol)
    ])
    error_message = "Backend service protocol must be one of: HTTP, HTTPS, HTTP2, TCP, SSL."
  }

  validation {
    condition = alltrue([
      for lb in var.load_balancers :
      contains(["NONE", "CLIENT_IP", "CLIENT_IP_PORT_PROTO", "CLIENT_IP_PROTO", "GENERATED_COOKIE", "HEADER_FIELD", "HTTP_COOKIE"], lb.backend_service.session_affinity)
    ])
    error_message = "Session affinity must be one of: NONE, CLIENT_IP, CLIENT_IP_PORT_PROTO, CLIENT_IP_PROTO, GENERATED_COOKIE, HEADER_FIELD, HTTP_COOKIE."
  }

  validation {
    condition = alltrue([
      for lb in var.load_balancers :
      lb.backend_service.max_utilization >= 0 && lb.backend_service.max_utilization <= 1
    ])
    error_message = "Backend service max_utilization must be between 0 and 1."
  }

  validation {
    condition = alltrue([
      for lb in var.load_balancers :
      lb.backend_service.log_sample_rate >= 0 && lb.backend_service.log_sample_rate <= 1
    ])
    error_message = "Backend service log_sample_rate must be between 0 and 1."
  }

  validation {
    condition = alltrue([
      for lb in var.load_balancers :
      lb.http_port >= 1 && lb.http_port <= 65535
    ])
    error_message = "HTTP port must be between 1 and 65535."
  }

  validation {
    condition = alltrue([
      for lb in var.load_balancers :
      lb.https_port >= 1 && lb.https_port <= 65535
    ])
    error_message = "HTTPS port must be between 1 and 65535."
  }

  validation {
    condition = alltrue([
      for lb in var.load_balancers :
      lb.health_check.port >= 1 && lb.health_check.port <= 65535
    ])
    error_message = "Health check port must be between 1 and 65535."
  }
}
