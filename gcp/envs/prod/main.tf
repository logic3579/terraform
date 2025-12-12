terraform {
  required_version = "~> 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0, < 8.0"  # Allow 5.x and 7.x
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0, < 8.0"  # Allow 5.x and 7.x
    }
  }

  backend "gcs" {}  # Configuration loaded from backend.hcl
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Use root module directly - variables defined in gcp/variables.tf
# Values provided via terraform.tfvars
module "gcp" {
  source = "../../"

  # All variables are automatically passed from terraform.tfvars
  env              = var.env
  labels           = merge(var.labels, { environment = var.env, managed_by = "terraform" })
  project_id       = var.project_id
  region           = var.region
  zone             = var.zone
  network_name     = var.network_name
  subnets          = var.subnets
  firewalls        = var.firewalls
  nat_configs      = var.nat_configs
  service_accounts = var.service_accounts
  iam_bindings     = var.iam_bindings
  gcs_buckets      = var.gcs_buckets
  vm_instances     = var.vm_instances
  instance_groups  = var.instance_groups
  load_balancers   = var.load_balancers
}
