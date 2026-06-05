# Terraform s3 backend pointed at OpenStack Swift's S3-compatible API.
#
# Generate Swift S3 (EC2) credentials once with:
#   openstack ec2 credentials create
# then export them in your shell:
#   export AWS_ACCESS_KEY_ID=<access>
#   export AWS_SECRET_ACCESS_KEY=<secret>

bucket = "tfstate"
key    = "openstack/dev/terraform.tfstate"
region = "RegionOne"

endpoints = {
  s3 = "https://swift.example.com:8080"
}

# Swift's S3 API doesn't implement all AWS-isms — disable the corresponding checks.
skip_credentials_validation = true
skip_region_validation      = true
skip_metadata_api_check     = true
skip_requesting_account_id  = true
use_path_style              = true
