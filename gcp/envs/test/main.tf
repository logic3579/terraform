terraform {
  backend "gcs" {
    bucket = "revosurge-uat-loki-chunks"
    prefix = "gcp/test"
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
  source = "../../../gcp"

  env         = var.env
  base_labels = var.base_labels
  project_id  = var.project_id
  region      = var.region
  zone        = var.zone

  subnets          = var.subnets
  firewalls        = var.firewalls
  service_accounts = var.service_accounts
  iam_bindings     = var.iam_bindings
  instances        = var.instances
  instance_groups  = var.instance_groups
}
