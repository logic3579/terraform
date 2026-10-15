# logic3579 environment configuration
# Provider, backend, and module wiring for the logic3579 project.

terraform {
  required_version = "~> 1.5"

  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.31"
    }
  }

  backend "s3" {} # Configuration loaded from backend.hcl
}

provider "vultr" {
  api_key     = var.api_key
  rate_limit  = var.rate_limit
  retry_limit = var.retry_limit
}

module "vultr" {
  source = "../../"

  vpcs            = var.vpcs
  firewall_groups = var.firewall_groups
  ssh_keys        = var.ssh_keys
  startup_scripts = var.startup_scripts
  instances       = var.instances
}
