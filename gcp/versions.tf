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
}
