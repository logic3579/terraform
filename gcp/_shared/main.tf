# Shared module call template for all environments
# This file is symlinked or copied to each environment directory

module "gcp" {
  source = "../../"

  # Core configuration
  env        = var.env
  labels     = merge(var.labels, { environment = var.env, managed_by = "terraform" })
  project_id = var.project_id
  region     = var.region
  zone       = var.zone

  # Network resources
  network_name = var.network_name
  subnets      = var.subnets
  firewalls    = var.firewalls

  # NAT resources
  nats = var.nats

  # IAM resources
  service_accounts = var.service_accounts
  iam_bindings     = var.iam_bindings

  # Storage resources
  buckets = var.buckets

  # Compute resources
  instances       = var.instances
  instance_groups = var.instance_groups

  # Load balancer resources
  load_balancers = var.load_balancers
}
