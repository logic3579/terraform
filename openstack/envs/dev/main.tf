# Dev environment configuration

terraform {
  required_version = "~> 1.5"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.4"
    }
  }

  # OpenStack Swift exposes an S3-compatible API; Terraform's native swift
  # backend was removed in 1.3, so the canonical OpenStack-native option now
  # is the s3 backend pointed at the Swift S3 endpoint.
  # Configuration loaded from backend.hcl.
  backend "s3" {}
}

provider "openstack" {
  auth_url            = var.auth_url
  region              = var.region
  user_name           = var.user_name
  password            = var.password
  tenant_name         = var.tenant_name
  user_domain_name    = var.user_domain_name
  project_domain_name = var.project_domain_name
  insecure            = var.insecure
}

module "openstack" {
  source = "../../"

  networks        = var.networks
  routers         = var.routers
  security_groups = var.security_groups
  floating_ips    = var.floating_ips
  keypairs        = var.keypairs
  instances       = var.instances
  volumes         = var.volumes
}
