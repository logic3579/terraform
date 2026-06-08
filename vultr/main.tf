// Root Vultr module: wires submodules together.
// Provider and backend configuration live in envs/<env>/main.tf.

# 1. Network — VPCs, firewall groups, firewall rules
module "network" {
  source = "./modules/network"

  vpcs            = var.vpcs
  firewall_groups = var.firewall_groups
}

# 2. Compute — SSH keys, startup scripts, instances
module "compute" {
  source = "./modules/compute"

  ssh_keys        = var.ssh_keys
  startup_scripts = var.startup_scripts
  instances       = var.instances

  # cross-module references resolved here
  vpc_id_by_name            = module.network.vpc_id_by_name
  firewall_group_id_by_name = module.network.firewall_group_id_by_name
}
