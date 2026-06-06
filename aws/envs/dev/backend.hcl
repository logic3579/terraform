# Terraform s3 backend pointed at Cloudflare R2 (S3-compatible).
#
# Create an R2 API token with S3 permissions in the Cloudflare dashboard,
# then export the credentials in your shell:
#   export AWS_ACCESS_KEY_ID=<r2-access-key-id>
#   export AWS_SECRET_ACCESS_KEY=<r2-secret-access-key>

bucket = "CHANGEME-terraform-state"
key    = "aws/dev/terraform.tfstate"
region = "auto"

endpoints = {
  s3 = "https://<CLOUDFLARE_ACCOUNT_ID>.r2.cloudflarestorage.com"
}

# R2 doesn't implement all AWS-isms — disable the corresponding checks.
skip_credentials_validation = true
skip_region_validation      = true
skip_metadata_api_check     = true
skip_requesting_account_id  = true
skip_s3_checksum            = true
use_path_style              = true
