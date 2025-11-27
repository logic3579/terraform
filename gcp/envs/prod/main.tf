terraform {
  backend "gcs" {
    bucket = "YOUR_TFSTATE_BUCKET"
    prefix = "gcp/prod"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

module "gcp" {
  source = "../../gcp"

  env        = var.env
  project_id = var.project_id
  region     = var.region
  zone       = var.zone

  subnets          = var.subnets
  iam_bindings     = var.iam_bindings
  service_accounts = var.service_accounts
  instances        = var.instances
  instance_groups  = var.instance_groups

  base_labels = var.base_labels
}
