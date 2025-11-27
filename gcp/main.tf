// Root GCP module: wiring submodules and example usage

terraform {
  # Backend configuration template (for direct root usage)
  # In most cases, you should configure the backend in envs/* as the actual root.
  # Uncomment and adjust when using this directory as the terraform root.
  # backend "gcs" {
  #   bucket  = "your-tfstate-bucket-name"
  #   prefix  = "gcp/env"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Example submodule wiring
module "network" {
  source       = "./modules/network"
  project_id   = var.project_id
  network_name = local.network_name
  subnets      = var.subnets
  firewalls    = var.firewalls
}

module "iam" {
  source           = "./modules/iam"
  project_id       = var.project_id
  service_accounts = var.service_accounts
  iam_bindings     = var.iam_bindings
}

# module "gce" {
#   source          = "./modules/gce"
#   project_id      = var.project_id
#   zone            = var.zone
#   instances       = var.instances
#   instance_groups = var.instance_groups
# }
