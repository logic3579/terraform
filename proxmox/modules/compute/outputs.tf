output "vms" {
  description = "VMs keyed by name"
  value = {
    for k, v in proxmox_virtual_environment_vm.this : k => {
      id        = v.id
      vm_id     = v.vm_id
      name      = v.name
      node_name = v.node_name
    }
  }
}
