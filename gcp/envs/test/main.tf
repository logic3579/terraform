# Test environment configuration
# Provider and module configuration loaded from _shared

terraform {
  required_version = "~> 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0"
    }
  }

  backend "gcs" {} # Configuration loaded from backend.hcl
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Root module call with standardized variable names
module "gcp" {
  source = "../../"

  # Core configuration
  env        = var.env
  labels     = merge(var.labels, { environment = var.env, managed_by = "terraform" })
  project_id = var.project_id
  region     = var.region
  zone       = var.zone

  # Network resources
  network_name = var.network_name
  subnets      = var.subnets
  firewalls    = var.firewalls

  # NAT resources
  nats = var.nats

  # IAM resources
  service_accounts = var.service_accounts
  iam_bindings     = var.iam_bindings

  # Storage resources
  buckets = var.buckets

  # Compute resources
  instances       = var.instances
  instance_groups = var.instance_groups

  # Load balancer resources
  load_balancers = var.load_balancers
}
