terraform {
  backend "gcs" {
    bucket = "revosurge-uat-loki-chunks"
    prefix = "gcp/dev"
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
