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
  labels      = merge(var.labels, { environment = var.env })
  network_name = var.network_name
  project_id  = var.project_id
  region      = var.region
  zone        = var.zone

  subnets          = var.subnets
  firewalls        = var.firewalls
  service_accounts = var.service_accounts
  iam_bindings     = var.iam_bindings
  gcs_buckets      = var.gcs_buckets
}
