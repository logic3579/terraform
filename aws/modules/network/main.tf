# ============================================================
# Locals — flatten nested inputs into maps with compound keys
# ============================================================

locals {
  subnets_flat = flatten([
    for vpc in var.vpcs : [
      for subnet in coalesce(vpc.subnets, []) : {
        key      = "${vpc.name}/${subnet.name}"
        vpc_name = vpc.name
        subnet   = subnet
      }
    ]
  ])

  nat_gateways_flat = flatten([
    for vpc in var.vpcs : [
      for nat in coalesce(vpc.nat_gateways, []) : {
        key      = "${vpc.name}/${nat.name}"
        vpc_name = vpc.name
        nat      = nat
      }
    ]
  ])

  security_groups_flat = flatten([
    for vpc in var.vpcs : [
      for sg in coalesce(vpc.security_groups, []) : {
        key      = "${vpc.name}/${sg.name}"
        vpc_name = vpc.name
        sg       = sg
      }
    ]
  ])

  ingress_rules_flat = flatten([
    for vpc in var.vpcs : [
      for sg in coalesce(vpc.security_groups, []) : [
        for i, rule in coalesce(sg.ingress_rules, []) : {
          key      = "${vpc.name}/${sg.name}/${i}"
          sg_key   = "${vpc.name}/${sg.name}"
          vpc_name = vpc.name
          rule     = rule
        }
      ]
    ]
  ])

  egress_rules_flat = flatten([
    for vpc in var.vpcs : [
      for sg in coalesce(vpc.security_groups, []) : [
        for i, rule in coalesce(sg.egress_rules, []) : {
          key      = "${vpc.name}/${sg.name}/${i}"
          sg_key   = "${vpc.name}/${sg.name}"
          vpc_name = vpc.name
          rule     = rule
        }
      ]
    ]
  ])

  # Identify VPCs that have at least one public subnet (need an IGW)
  vpcs_with_public_subnets = toset([
    for vpc in var.vpcs : vpc.name
    if anytrue([for s in coalesce(vpc.subnets, []) : coalesce(s.public, false)])
  ])

  # Private subnets that reference a NAT gateway
  private_subnets_with_nat = {
    for s in local.subnets_flat : s.key => s
    if s.subnet.nat_gateway_name != null
  }

  # Build a map of NAT gateway key → route table key for private subnet associations
  nat_route_table_keys = {
    for nat in local.nat_gateways_flat : "${nat.vpc_name}/${nat.nat.name}" => nat.key
  }
}

# ============================================================
# VPCs
# ============================================================

resource "aws_vpc" "this" {
  for_each = { for vpc in var.vpcs : vpc.name => vpc }

  cidr_block           = each.value.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, each.value.tags, {
    Name = each.key
  })
}

# ============================================================
# Subnets
# ============================================================

resource "aws_subnet" "this" {
  for_each = { for s in local.subnets_flat : s.key => s }

  vpc_id                  = aws_vpc.this[each.value.vpc_name].id
  cidr_block              = each.value.subnet.cidr_block
  availability_zone       = each.value.subnet.availability_zone
  map_public_ip_on_launch = coalesce(each.value.subnet.public, false)

  tags = merge(var.tags, each.value.subnet.tags, {
    Name = each.value.subnet.name
  })
}

# ============================================================
# Internet Gateways — one per VPC that has public subnets
# ============================================================

resource "aws_internet_gateway" "this" {
  for_each = local.vpcs_with_public_subnets

  vpc_id = aws_vpc.this[each.key].id

  tags = merge(var.tags, {
    Name = "${each.key}-igw"
  })
}

# ============================================================
# NAT Gateways + Elastic IPs
# ============================================================

resource "aws_eip" "nat" {
  for_each = { for n in local.nat_gateways_flat : n.key => n }

  domain = "vpc"

  tags = merge(var.tags, each.value.nat.tags, {
    Name = "${each.value.nat.name}-eip"
  })
}

resource "aws_nat_gateway" "this" {
  for_each = { for n in local.nat_gateways_flat : n.key => n }

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.this["${each.value.vpc_name}/${each.value.nat.subnet_name}"].id

  tags = merge(var.tags, each.value.nat.tags, {
    Name = each.value.nat.name
  })

  depends_on = [aws_internet_gateway.this]
}

# ============================================================
# Route Tables
# ============================================================

# Public route table — one per VPC with public subnets
resource "aws_route_table" "public" {
  for_each = local.vpcs_with_public_subnets

  vpc_id = aws_vpc.this[each.key].id

  tags = merge(var.tags, {
    Name = "${each.key}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  for_each = local.vpcs_with_public_subnets

  route_table_id         = aws_route_table.public[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[each.key].id
}

# Private route table — one per NAT gateway
resource "aws_route_table" "private" {
  for_each = { for n in local.nat_gateways_flat : n.key => n }

  vpc_id = aws_vpc.this[each.value.vpc_name].id

  tags = merge(var.tags, {
    Name = "${each.value.nat.name}-private-rt"
  })
}

resource "aws_route" "private_nat" {
  for_each = { for n in local.nat_gateways_flat : n.key => n }

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}

# ============================================================
# Route Table Associations
# ============================================================

# Public subnets → public route table
resource "aws_route_table_association" "public" {
  for_each = {
    for s in local.subnets_flat : s.key => s
    if coalesce(s.subnet.public, false)
  }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public[each.value.vpc_name].id
}

# Private subnets with NAT → private route table (keyed by NAT gateway)
resource "aws_route_table_association" "private" {
  for_each = local.private_subnets_with_nat

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.private["${each.value.vpc_name}/${each.value.subnet.nat_gateway_name}"].id
}

# ============================================================
# Security Groups
# ============================================================

resource "aws_security_group" "this" {
  for_each = { for sg in local.security_groups_flat : sg.key => sg }

  name        = each.value.sg.name
  description = coalesce(each.value.sg.description, "Managed by Terraform")
  vpc_id      = aws_vpc.this[each.value.vpc_name].id

  tags = merge(var.tags, each.value.sg.tags, {
    Name = each.value.sg.name
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================
# Security Group Rules
# ============================================================

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = { for r in local.ingress_rules_flat : r.key => r }

  security_group_id = aws_security_group.this[each.value.sg_key].id
  description       = coalesce(each.value.rule.description, "")
  from_port         = each.value.rule.from_port
  to_port           = each.value.rule.to_port
  ip_protocol       = each.value.rule.protocol
  cidr_ipv4         = length(coalesce(each.value.rule.cidr_blocks, [])) > 0 ? each.value.rule.cidr_blocks[0] : null

  tags = merge(var.tags, {
    Name = "ingress-${each.key}"
  })
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = { for r in local.egress_rules_flat : r.key => r }

  security_group_id = aws_security_group.this[each.value.sg_key].id
  description       = coalesce(each.value.rule.description, "")
  from_port         = each.value.rule.from_port
  to_port           = each.value.rule.to_port
  ip_protocol       = each.value.rule.protocol
  cidr_ipv4         = length(coalesce(each.value.rule.cidr_blocks, [])) > 0 ? each.value.rule.cidr_blocks[0] : null

  tags = merge(var.tags, {
    Name = "egress-${each.key}"
  })
}
