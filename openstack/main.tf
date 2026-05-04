// Root OpenStack module: wires submodules together.
// Provider and backend configuration live in envs/<env>/main.tf.

# 1. Network — networks, subnets, routers, security groups, floating IPs
module "network" {
  source = "./modules/network"

  networks        = var.networks
  routers         = var.routers
  security_groups = var.security_groups
  floating_ips    = var.floating_ips
}

# 2. Storage — Cinder block volumes
module "storage" {
  source  = "./modules/storage"
  volumes = var.volumes
}

# 3. Compute — instances, keypairs (depends on network for nuid lookups)
module "compute" {
  source = "./modules/compute"

  keypairs  = var.keypairs
  instances = var.instances

  # cross-module references resolved here
  network_id_by_name = module.network.network_id_by_name
  volume_id_by_name  = module.storage.volume_id_by_name
}
