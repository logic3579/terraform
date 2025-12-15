// Root GCP module: wiring submodules
// Note: This is a reusable module. Provider and backend configuration
// should be defined in the environment-specific configurations (envs/*).

# 1. Network infrastructure (VPC, subnets, firewalls)
module "network" {
  source     = "./modules/network"
  project_id = var.project_id
  networks   = var.networks
}

# 2. NAT configuration (depends on network)
module "nat" {
  source     = "./modules/nat"
  project_id = var.project_id
  labels     = var.labels
  nats       = var.nats
}

# 3. IAM resources (service accounts and bindings)
module "iam" {
  source           = "./modules/iam"
  project_id       = var.project_id
  service_accounts = var.service_accounts
  iam_bindings     = var.iam_bindings
}

# 4. Storage resources (GCS buckets)
module "storage" {
  source     = "./modules/storage"
  project_id = var.project_id
  buckets    = var.buckets
  labels     = var.labels
}

# 5. Compute resources (VM instances and instance groups)
module "compute" {
  source          = "./modules/compute"
  project_id      = var.project_id
  labels          = var.labels
  instances       = var.instances
  instance_groups = var.instance_groups
}

# 6. Load balancer resources (depends on compute)
# Transform load_balancers to replace instance_group names with self_links
locals {
  load_balancers_with_self_links = [
    for lb in var.load_balancers : merge(lb, {
      backend_service = merge(lb.backend_service, {
        instance_groups = [
          for ig_name in lb.backend_service.instance_groups :
          module.compute.instance_group_self_links[ig_name]
        ]
      })
    })
  ]
}

module "lb" {
  source         = "./modules/lb"
  project_id     = var.project_id
  labels         = var.labels
  load_balancers = local.load_balancers_with_self_links
}
