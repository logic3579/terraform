# Dev/Test environment configuration
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
  region = "us-east-1"

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
  env  = var.env
  tags = merge(var.tags, { environment = var.env, managed_by = "terraform" })

  # Network resources
  vpcs = var.vpcs
}
