// Root GCP module: wiring submodules and example usage
// Note: This is a reusable module. Provider and backend configuration
// should be defined in the environment-specific configurations (envs/*).

# Example submodule wiring
module "network" {
  source       = "./modules/network"
  project_id   = var.project_id
  network_name = var.network_name
  subnets      = var.subnets
  firewalls    = var.firewalls
}

module "nat" {
  source      = "./modules/nat"
  project_id  = var.project_id
  nat_configs = var.nat_configs
}

module "iam" {
  source           = "./modules/iam"
  project_id       = var.project_id
  service_accounts = var.service_accounts
  iam_bindings     = var.iam_bindings
}

module "gcs" {
  source      = "./modules/gcs"
  project_id  = var.project_id
  gcs_buckets = var.gcs_buckets
  labels      = var.labels
}

module "gce" {
  source          = "./modules/gce"
  project_id      = var.project_id
  vm_instances    = var.vm_instances
  instance_groups = var.instance_groups
}

# Transform load_balancers to replace instance_group names with self_links
locals {
  load_balancers_with_self_links = [
    for lb in var.load_balancers : merge(lb, {
      backend_service = merge(lb.backend_service, {
        instance_groups = [
          for ig_name in lb.backend_service.instance_groups :
          module.gce.instance_group_self_links[ig_name]
        ]
      })
    })
  ]
}

module "lb" {
  source         = "./modules/lb"
  project_id     = var.project_id
  load_balancers = local.load_balancers_with_self_links
}