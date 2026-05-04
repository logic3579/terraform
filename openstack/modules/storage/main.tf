data "openstack_images_image_v2" "volume" {
  for_each    = toset([for v in var.volumes : v.image_name if v.image_name != null])
  name        = each.value
  most_recent = true
}

resource "openstack_blockstorage_volume_v3" "this" {
  for_each = { for v in var.volumes : v.name => v }

  name              = each.value.name
  description       = each.value.description
  size              = each.value.size
  volume_type       = each.value.volume_type
  availability_zone = each.value.availability_zone
  image_id          = each.value.image_name != null ? data.openstack_images_image_v2.volume[each.value.image_name].id : null
  metadata          = each.value.metadata
}
