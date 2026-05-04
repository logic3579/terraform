output "instances" {
  description = "Instances keyed by name"
  value = {
    for k, v in openstack_compute_instance_v2.this : k => {
      id           = v.id
      name         = v.name
      access_ip_v4 = v.access_ip_v4
    }
  }
}

output "keypairs" {
  description = "Keypairs keyed by name"
  value = {
    for k, v in openstack_compute_keypair_v2.this : k => {
      name        = v.name
      fingerprint = v.fingerprint
    }
  }
}
