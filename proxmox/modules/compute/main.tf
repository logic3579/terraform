resource "proxmox_virtual_environment_vm" "this" {
  for_each = { for vm in var.vms : vm.name => vm }

  name        = each.value.name
  node_name   = each.value.node_name
  vm_id       = each.value.vm_id
  description = each.value.description
  tags        = each.value.tags
  started     = each.value.started
  on_boot     = each.value.on_boot

  cpu {
    cores   = each.value.cpu_cores
    sockets = each.value.cpu_sockets
    type    = each.value.cpu_type
  }

  memory {
    dedicated = each.value.memory_dedicated
  }

  agent {
    enabled = each.value.agent_enabled
  }

  dynamic "disk" {
    for_each = each.value.disks
    content {
      interface    = disk.value.interface
      datastore_id = disk.value.datastore_id
      size         = disk.value.size
      file_format  = disk.value.file_format
      file_id      = disk.value.file_id
    }
  }

  dynamic "network_device" {
    for_each = each.value.network_devices
    content {
      bridge  = network_device.value.bridge
      model   = network_device.value.model
      vlan_id = network_device.value.vlan_id
    }
  }

  dynamic "initialization" {
    for_each = each.value.cloud_init != null ? [each.value.cloud_init] : []
    content {
      datastore_id = initialization.value.datastore_id

      dynamic "user_account" {
        for_each = (
          initialization.value.username != null ||
          initialization.value.password != null ||
          length(coalesce(initialization.value.ssh_keys, [])) > 0
        ) ? [1] : []
        content {
          username = initialization.value.username
          password = initialization.value.password
          keys     = initialization.value.ssh_keys
        }
      }

      dynamic "ip_config" {
        for_each = initialization.value.ipv4_address != null ? [1] : []
        content {
          ipv4 {
            address = initialization.value.ipv4_address
            gateway = initialization.value.ipv4_gateway
          }
        }
      }

      dynamic "dns" {
        for_each = (
          length(coalesce(initialization.value.dns_servers, [])) > 0 ||
          initialization.value.dns_domain != null
        ) ? [1] : []
        content {
          servers = initialization.value.dns_servers
          domain  = initialization.value.dns_domain
        }
      }
    }
  }
}
