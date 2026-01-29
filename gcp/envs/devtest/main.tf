# Test environment configuration
# Provider and module configuration loaded from _shared

terraform {
  required_version = "~> 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.0"
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
  networks = var.networks

  # NAT resources
  nats = var.nats

  # IAM resources
  service_accounts           = var.service_accounts
  iam_bindings               = var.iam_bindings
  workload_identity_bindings = var.workload_identity_bindings

  # Storage resources
  buckets = var.buckets

  # Compute resources
  instances       = var.instances
  instance_groups = var.instance_groups

  # Load balancer resources
  load_balancers = var.load_balancers
}
