output "vpcs" {
  description = "Map of VPC resources keyed by VPC name"
  value = {
    for k, v in aws_vpc.this : k => {
      id         = v.id
      arn        = v.arn
      cidr_block = v.cidr_block
    }
  }
}

output "subnets" {
  description = "Map of subnet resources keyed by vpc-name/subnet-name"
  value = {
    for k, v in aws_subnet.this : k => {
      id                = v.id
      arn               = v.arn
      cidr_block        = v.cidr_block
      availability_zone = v.availability_zone
      vpc_id            = v.vpc_id
    }
  }
}

output "internet_gateways" {
  description = "Map of internet gateways keyed by VPC name"
  value = {
    for k, v in aws_internet_gateway.this : k => {
      id = v.id
    }
  }
}

output "nat_gateways" {
  description = "Map of NAT gateways keyed by vpc-name/nat-name"
  value = {
    for k, v in aws_nat_gateway.this : k => {
      id        = v.id
      public_ip = v.public_ip
      subnet_id = v.subnet_id
    }
  }
}

output "security_groups" {
  description = "Map of security groups keyed by vpc-name/sg-name"
  value = {
    for k, v in aws_security_group.this : k => {
      id     = v.id
      arn    = v.arn
      name   = v.name
      vpc_id = v.vpc_id
    }
  }
}
