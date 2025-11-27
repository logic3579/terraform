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