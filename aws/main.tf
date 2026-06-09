# ============================================================
# Network
# ============================================================

module "network" {
  source = "./modules/network"

  vpcs = var.vpcs
  tags = var.tags
}

# ============================================================
# IAM (EC2 instance profiles + Lambda execution roles)
# ============================================================

module "iam" {
  source = "./modules/iam"

  ec2_instance_profiles  = var.ec2_instance_profiles
  lambda_execution_roles = var.lambda_execution_roles
  iam_users              = var.iam_users
  tags                   = var.tags
}

# ============================================================
# Compute (EC2)
# ============================================================

module "compute" {
  source = "./modules/compute"

  instances = var.instances
  key_pairs = var.key_pairs

  subnet_ids_by_name         = { for k, v in module.network.subnets : k => v.id }
  security_group_ids_by_name = { for k, v in module.network.security_groups : k => v.id }
  iam_instance_profile_names = module.iam.ec2_instance_profile_names

  tags = var.tags
}

# ============================================================
# RDS
# ============================================================

module "rds" {
  source = "./modules/rds"

  rds_instances              = var.rds_instances
  subnet_ids_by_name         = { for k, v in module.network.subnets : k => v.id }
  security_group_ids_by_name = { for k, v in module.network.security_groups : k => v.id }

  tags = var.tags
}

# ============================================================
# Lambda
# ============================================================

module "lambda" {
  source = "./modules/lambda"

  lambda_functions = var.lambda_functions
  lambda_role_arns = module.iam.lambda_role_arns

  tags = var.tags
}

# ============================================================
# Budgets
# ============================================================

module "budget" {
  source = "./modules/budget"

  budgets = var.budgets
  tags    = var.tags
}
