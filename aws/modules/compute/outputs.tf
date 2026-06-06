output "instances" {
  description = "Map of EC2 instances keyed by name."
  value = {
    for k, v in aws_instance.this : k => {
      id            = v.id
      arn           = v.arn
      ami           = v.ami
      instance_type = v.instance_type
      subnet_id     = v.subnet_id
      public_ip     = v.public_ip
      private_ip    = v.private_ip
      public_dns    = v.public_dns
      private_dns   = v.private_dns
      eip           = try(aws_eip.this[k].public_ip, null)
    }
  }
}

output "elastic_ips" {
  description = "Map of Elastic IPs keyed by instance name."
  value = {
    for k, v in aws_eip.this : k => {
      id        = v.id
      public_ip = v.public_ip
    }
  }
}

output "key_pairs" {
  description = "Map of key pairs keyed by key name."
  value = {
    for k, v in aws_key_pair.this : k => {
      key_name    = v.key_name
      fingerprint = v.fingerprint
    }
  }
}
