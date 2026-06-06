# ============================================================
# Locals
# ============================================================

locals {
  rds_by_name = { for r in var.rds_instances : r.name => r }
}

# ============================================================
# Master password — random_password + SSM Parameter Store
# ============================================================

resource "random_password" "master" {
  for_each = local.rds_by_name

  length  = 24
  special = true
  # Avoid characters that commonly trip up RDS / shell escaping
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "master_password" {
  for_each = local.rds_by_name

  name        = coalesce(each.value.ssm_password_path, "/${each.value.name}/master_password")
  description = "Master password for RDS instance ${each.value.name}"
  type        = "SecureString"
  value       = random_password.master[each.key].result

  tags = merge(var.tags, each.value.tags)
}

# ============================================================
# DB subnet group
# ============================================================

resource "aws_db_subnet_group" "this" {
  for_each = local.rds_by_name

  name = "${each.value.name}-subnet-group"
  subnet_ids = [
    for s in each.value.subnet_names :
    var.subnet_ids_by_name[s]
  ]

  tags = merge(var.tags, each.value.tags, {
    Name = "${each.value.name}-subnet-group"
  })
}

# ============================================================
# DB instance
# ============================================================

resource "aws_db_instance" "this" {
  for_each = local.rds_by_name

  identifier        = each.value.name
  engine            = each.value.engine
  engine_version    = each.value.engine_version
  instance_class    = each.value.instance_class
  allocated_storage = each.value.allocated_storage
  storage_type      = each.value.storage_type
  storage_encrypted = each.value.storage_encrypted

  db_name  = each.value.db_name
  username = each.value.username
  password = random_password.master[each.key].result
  port     = each.value.port

  db_subnet_group_name = aws_db_subnet_group.this[each.key].name
  vpc_security_group_ids = [
    for s in each.value.security_group_names :
    var.security_group_ids_by_name[s]
  ]

  publicly_accessible     = each.value.publicly_accessible
  multi_az                = each.value.multi_az
  backup_retention_period = each.value.backup_retention_days
  skip_final_snapshot     = each.value.skip_final_snapshot
  deletion_protection     = each.value.deletion_protection
  apply_immediately       = each.value.apply_immediately

  tags = merge(var.tags, each.value.tags, {
    Name = each.value.name
  })

  lifecycle {
    ignore_changes = [
      # Allow AWS-side patching to bump the minor version without Terraform replacing the instance.
      engine_version,
    ]
  }
}
