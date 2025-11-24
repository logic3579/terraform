# GCP Variables
variable "project_id" {
  description = "The ID of the GCP project"
  type        = string
  default     = "your-project-id"
}

variable "project_name" {
  description = "The name of the GCP project"
  type        = string
  default     = "your-project-name"
}

# 默认区域和可用区
variable "default_region" {
  description = "The default GCP region"
  type        = string
  default     = "asia-southeast1"
}

variable "default_zone" {
  description = "The default GCP zone"
  type        = string
  default     = "asia-southeast1-a"
}

# 现有 VPC 配置
variable "current_vpc_name" {
  description = "The name of the current VPC network"
  type        = string
  default     = "default"
}

# 防火墙规则配置
variable "firewall_rules" {
  description = "Configuration for firewall rules"
  type = map(object({
    name          = string
    description   = optional(string)
    priority      = optional(number)
    source_ranges = list(string)
    target_tags   = optional(list(string))
    allow = list(object({
      protocol = string
      ports    = optional(list(string))
    }))
  }))
  default = {}
}

# 多区域子网配置
variable "subnet_configs" {
  description = "Configuration for subnets in different regions"
  type = map(object({
    region             = string
    primary_ipv4_range = string
  }))
  default = {
    "algorithm-ew1" = {
      region             = "europe-west1"
      primary_ipv4_range = "172.20.10.0/24"
    }
    "algorithm-uc1" = {
      region             = "us-central1"
      primary_ipv4_range = "172.20.11.0/24"
    }
    "algorithm-as1" = {
      region             = "asia-southeast1"
      primary_ipv4_range = "172.20.12.0/24"
    }
  }
}

# 多 VM 实例配置
variable "vm_instances" {
  description = "Configuration for VM instances in different regions"
  type = map(object({
    instances = list(object({
      name          = string
      machine_type  = string
      region        = string
      zone          = string
      image_family  = string
      image_project = string
      disk_size     = number
      disk_type     = string
      network_tags  = list(string)
      network       = string
      subnetwork    = string
    }))
  }))
  default = {
    "europe-west1" = {
      instances = [
        {
          name          = "default-vm"
          machine_type  = "e2-small"
          region        = "europe-west2"
          zone          = "europe-west2-a"
          image_family  = "ubuntu-2204-lts"
          image_project = "ubuntu-os-cloud"
          disk_size     = 20
          disk_type     = "pd-balanced"
          network_tags  = ["algorithm"]
          network       = "default"
          subnetwork    = "algorithm-ew1"
        }
      ]
    }
  }
}

# Instance Group 配置
variable "instance_groups" {
  description = "Configuration for instance groups"
  type = map(object({
    name        = string
    description = string
    zone        = string
    instances   = list(string) # VM instance keys in format "region-index"
    named_ports = list(object({
      name = string
      port = number
    }))
  }))
  default = {}
}

# Load Balancer 配置
variable "lb_name" {
  description = "Name of the load balancer"
  type        = string
  default     = "ortb-lb"
}

variable "lb_external_ip_name" {
  description = "Name of the load balancer external IP address"
  type        = string
  default     = "ortb-lb-external-ip"
}

variable "lb_forwarding_rule_name" {
  description = "Name of the load balancer forwarding rule"
  type        = string
  default     = "ortb-lb-forwarding-rule"
}

variable "lb_backend_service_name" {
  description = "Name of the backend service"
  type        = string
  default     = "ortb-global-backend"
}

variable "lb_health_check_name" {
  description = "Name of the health check"
  type        = string
  default     = "ortb-health-check"
}

variable "lb_backends" {
  description = "Configuration for load balancer backends"
  type = map(object({
    instance_group_key    = string # Instance group key from instance_groups variable
    balancing_mode        = optional(string, "UTILIZATION")
    capacity_scaler       = optional(number, 1.0)
    max_utilization       = optional(number, 0.8)
    max_rate_per_instance = optional(number) # Added max_rate_per_instance field
  }))
  default = {}
}

# HTTPS SSL 证书变量
variable "lb_ssl_certificate_name" {
  description = "Name for Google-managed SSL certificate (for HTTPS frontend)"
  type        = string
  default     = "ortb-ssl-cert"
}

variable "lb_ssl_certificate_domains" {
  description = "Domain list to bind for Google-managed classic certificate"
  type        = list(string)
  default     = ["example.com"]
}

# ========================================
# GCS Bucket 配置
# ========================================

variable "gcs_buckets" {
  description = "GCS Buckets configuration"
  type = map(object({
    name               = string
    location           = string # Region name (e.g., "asia-southeast1")
    storage_class      = optional(string, "STANDARD")
    prevention_rule    = optional(string, "enforced")
    versioning_enabled = optional(bool, false)
    labels             = optional(map(string), {})
    lifecycle_rules = optional(list(object({
      action = object({
        type          = string
        storage_class = optional(string)
      })
      condition = object({
        age                   = optional(number)
        created_before        = optional(string)
        with_state            = optional(string)
        matches_storage_class = optional(list(string))
        num_newer_versions    = optional(number)
      })
    })), [])
  }))
  default = {}
}

# ========================================
# IAM Service Account 配置
# ========================================

variable "service_accounts" {
  description = "Service Accounts configuration"
  type = map(object({
    account_id       = string
    display_name     = string
    description      = optional(string, "")
    roles            = list(string)          # List of IAM roles to assign
    create_key       = optional(bool, false) # Whether to create a key
    save_key_to_file = optional(bool, false) # Whether to save key to file
  }))
  default = {}
}

# 网络配置说明
# VM 使用静态外部 IP 地址
