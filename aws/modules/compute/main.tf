# ============================================================
# Locals — AMI lookup presets and instance-by-name index
# ============================================================

locals {
  os_ami_filters = {
    debian-12 = {
      owners       = ["136693071363"]
      name_pattern = "debian-12-amd64-*"
    }
    al2023 = {
      owners       = ["amazon"]
      name_pattern = "al2023-ami-*-x86_64"
    }
    ubuntu-22 = {
      owners       = ["099720109477"]
      name_pattern = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
    }
  }

  instances_by_name = { for inst in var.instances : inst.name => inst }

  instances_with_os_lookup = {
    for inst in var.instances : inst.name => inst
    if inst.ami_id == null && inst.os != null
  }
}

# ============================================================
# AMI lookups (only for instances that use an os preset)
# ============================================================

data "aws_ami" "this" {
  for_each = local.instances_with_os_lookup

  most_recent = true
  owners      = local.os_ami_filters[each.value.os].owners

  filter {
    name   = "name"
    values = [local.os_ami_filters[each.value.os].name_pattern]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ============================================================
# Key pairs
# ============================================================

resource "aws_key_pair" "this" {
  for_each = { for k in var.key_pairs : k.name => k }

  key_name   = each.value.name
  public_key = each.value.public_key

  tags = merge(var.tags, {
    Name = each.value.name
  })
}

# ============================================================
# EC2 Instances
# ============================================================

resource "aws_instance" "this" {
  for_each = local.instances_by_name

  ami           = coalesce(each.value.ami_id, try(data.aws_ami.this[each.key].id, null))
  instance_type = each.value.instance_type

  subnet_id = var.subnet_ids_by_name[each.value.subnet_name]

  vpc_security_group_ids = [
    for sg_name in coalesce(each.value.security_group_names, []) :
    var.security_group_ids_by_name[sg_name]
  ]

  associate_public_ip_address = each.value.associate_public_ip
  key_name                    = each.value.key_name
  iam_instance_profile        = each.value.iam_instance_profile != null ? var.iam_instance_profile_names[each.value.iam_instance_profile] : null
  user_data                   = each.value.user_data

  root_block_device {
    volume_size           = each.value.root_volume.size_gb
    volume_type           = each.value.root_volume.type
    delete_on_termination = each.value.root_volume.delete_on_termination
    encrypted             = each.value.root_volume.encrypted
  }

  # IMDSv2 only (defense-in-depth)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = merge(var.tags, each.value.tags, {
    Name = each.value.name
  })

  lifecycle {
    ignore_changes = [
      # user_data only runs on first boot; ignore in-place changes to avoid replace on rerun.
      user_data,
    ]
  }
}

# ============================================================
# Elastic IPs (optional, per-instance)
# ============================================================

resource "aws_eip" "this" {
  for_each = {
    for inst in var.instances : inst.name => inst
    if coalesce(inst.eip, false)
  }

  instance = aws_instance.this[each.key].id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${each.key}-eip"
  })
}
