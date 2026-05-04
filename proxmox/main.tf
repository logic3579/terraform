// Root Proxmox module: wires submodules together.
// Provider and backend configuration live in envs/<env>/main.tf.

# 1. Network — Linux bridges on PVE nodes
module "network" {
  source  = "./modules/network"
  bridges = var.bridges
}

# 2. Storage — ISOs / cloud images / LXC templates downloaded into PVE datastores
module "storage" {
  source         = "./modules/storage"
  download_files = var.download_files
}

# 3. Compute — KVM virtual machines
module "compute" {
  source = "./modules/compute"
  vms    = var.vms
}
