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

  env        = var.env
  labels     = merge(var.labels, { environment = var.env })
  project_id = var.project_id
  region     = var.region
  zone       = var.zone

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
