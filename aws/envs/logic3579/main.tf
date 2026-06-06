# logic3579 environment configuration
# Provider and module configuration loaded from _shared

terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {} # Configuration loaded from backend.hcl
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Environment = var.env
      ManagedBy   = "terraform"
    }
  }
}

# Root module call with standardized variable names
module "aws" {
  source = "../../"

  # Core configuration
  env    = var.env
  region = var.region
  # Environment + ManagedBy come through the provider's default_tags block,
  # so don't duplicate them here (IAM tag keys are case-insensitive and would clash).
  tags = var.tags

  # Network resources
  vpcs = var.vpcs

  # IAM resources
  ec2_instance_profiles  = var.ec2_instance_profiles
  lambda_execution_roles = var.lambda_execution_roles

  # Compute resources
  key_pairs = var.key_pairs
  instances = var.instances

  # RDS resources
  rds_instances = var.rds_instances

  # Lambda functions
  lambda_functions = var.lambda_functions

  # Budgets
  budgets = var.budgets
}
