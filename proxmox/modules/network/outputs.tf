output "bridges" {
  description = "Linux bridges keyed by node_name/bridge_name"
  value = {
    for k, v in proxmox_virtual_environment_network_linux_bridge.this : k => {
      id        = v.id
      node_name = v.node_name
      name      = v.name
    }
  }
}
