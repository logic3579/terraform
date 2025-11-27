output "instances" {
  description = "Instances created by this module"
  value = [
    for name, inst in google_compute_instance.this : {
      name      = inst.name
      self_link = inst.self_link
      zone      = inst.zone
    }
  ]
}

output "instance_groups" {
  description = "Instance groups created by this module"
  value = [
    for name, grp in google_compute_instance_group.this : {
      name      = grp.name
      self_link = grp.self_link
      zone      = grp.zone
    }
  ]
}
