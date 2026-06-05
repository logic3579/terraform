# Dev environment configuration
# Provider, backend, and module wiring for the dev env.

terraform {
  required_version = "~> 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.104.0"
    }
  }

  # Local backend — Proxmox has no native Terraform backend; community
  # convention is local state (or S3-compatible like MinIO for teams).
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "proxmox" {
  endpoint  = var.endpoint
  insecure  = var.insecure
  api_token = var.api_token
  username  = var.username
  password  = var.password

  dynamic "ssh" {
    for_each = var.ssh_username != null ? [1] : []
    content {
      agent       = var.ssh_agent
      username    = var.ssh_username
      private_key = var.ssh_private_key
    }
  }
}

module "proxmox" {
  source = "../../"

  bridges        = var.bridges
  download_files = var.download_files
  vms            = var.vms
}
