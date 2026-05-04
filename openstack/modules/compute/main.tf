# Lookup Glance images by name for instances that boot from image
data "openstack_images_image_v2" "instance" {
  for_each    = toset([for i in var.instances : i.image_name if i.image_name != null && i.boot_volume_name == null])
  name        = each.value
  most_recent = true
}

# Lookup flavors by name (private flavors aren't supported via name; create them out-of-band)
data "openstack_compute_flavor_v2" "instance" {
  for_each = toset([for i in var.instances : i.flavor_name])
  name     = each.value
}

resource "openstack_compute_keypair_v2" "this" {
  for_each = { for k in var.keypairs : k.name => k }

  name       = each.value.name
  public_key = each.value.public_key
}

resource "openstack_compute_instance_v2" "this" {
  for_each = { for i in var.instances : i.name => i }

  name              = each.value.name
  flavor_id         = data.openstack_compute_flavor_v2.instance[each.value.flavor_name].id
  image_id          = each.value.boot_volume_name == null && each.value.image_name != null ? data.openstack_images_image_v2.instance[each.value.image_name].id : null
  key_pair          = each.value.keypair_name != null ? openstack_compute_keypair_v2.this[each.value.keypair_name].name : null
  user_data         = each.value.user_data
  metadata          = each.value.metadata
  availability_zone = each.value.availability_zone
  security_groups   = each.value.security_groups

  dynamic "network" {
    for_each = each.value.networks
    content {
      uuid        = var.network_id_by_name[network.value.network_name]
      fixed_ip_v4 = network.value.fixed_ip_v4
    }
  }

  # Boot from a pre-existing Cinder volume (created by the storage module)
  dynamic "block_device" {
    for_each = each.value.boot_volume_name != null ? [1] : []
    content {
      uuid                  = var.volume_id_by_name[each.value.boot_volume_name]
      source_type           = "volume"
      destination_type      = "volume"
      boot_index            = 0
      delete_on_termination = false
    }
  }
}
