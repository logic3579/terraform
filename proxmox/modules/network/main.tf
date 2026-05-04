# Using the legacy SDKv2 resource name. The Plugin Framework rewrite shipped
# in v0.105.0 (`proxmox_network_linux_bridge`) has a schema bug on `ports`
# that breaks `terraform validate`; provider is pinned to ~> 0.104.0 in
# versions.tf until that is fixed upstream.
resource "proxmox_virtual_environment_network_linux_bridge" "this" {
  for_each = { for b in var.bridges : "${b.node_name}/${b.name}" => b }

  node_name  = each.value.node_name
  name       = each.value.name
  address    = each.value.address
  gateway    = each.value.gateway
  comment    = each.value.comment
  ports      = each.value.ports
  vlan_aware = each.value.vlan_aware
  mtu        = each.value.mtu
}
