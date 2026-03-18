#!/bin/bash
# Sync terraform.tfvars with GCS backend bucket
# Usage: ./scripts/tfvars-sync.sh <upload|download> [environment]
#
# Examples:
#   ./scripts/tfvars-sync.sh download           # Download all environments
#   ./scripts/tfvars-sync.sh download devtest   # Download specific environment
#   ./scripts/tfvars-sync.sh upload             # Upload all environments
#   ./scripts/tfvars-sync.sh upload prod        # Upload specific environment

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ACTION="${1:-}"
TARGET_ENV="${2:-}"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GCP_DIR="$(dirname "$SCRIPT_DIR")"
ENVS_DIR="$GCP_DIR/envs"

usage() {
  echo "Usage: $0 <upload|download> [environment]"
  echo ""
  echo "Actions:"
  echo "  upload    - Upload terraform.tfvars to GCS bucket"
  echo "  download  - Download terraform.tfvars from GCS bucket"
  echo ""
  echo "Options:"
  echo "  environment - Specific environment (e.g., devtest, prod)"
  echo "                If omitted, syncs all environments"
  echo ""
  echo "Examples:"
  echo "  $0 download              # Download all environments"
  echo "  $0 download devtest      # Download devtest only"
  echo "  $0 upload                # Upload all environments"
  echo "  $0 upload prod           # Upload prod only"
  echo ""
  echo "Available environments:"
  find "$ENVS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort
  exit 1
}

# Validate action
if [[ -z "$ACTION" ]] || [[ ! "$ACTION" =~ ^(upload|download)$ ]]; then
  usage
fi

# Get bucket name from backend.hcl
get_bucket() {
  local env="$1"
  local backend_file="$ENVS_DIR/$env/backend.hcl"

  if [[ ! -f "$backend_file" ]]; then
    echo ""
    return
  fi

  # Extract value between quotes (compatible with macOS and Linux)
  grep '^bucket' "$backend_file" | cut -d'"' -f2
}

# Get prefix from backend.hcl
get_prefix() {
  local env="$1"
  local backend_file="$ENVS_DIR/$env/backend.hcl"

  if [[ ! -f "$backend_file" ]]; then
    echo ""
    return
  fi

  # Extract value between quotes (compatible with macOS and Linux)
  grep '^prefix' "$backend_file" | cut -d'"' -f2
}

# Upload tfvars to GCS
upload_tfvars() {
  local env="$1"
  local tfvars_file="$ENVS_DIR/$env/terraform.tfvars"
  local bucket prefix gcs_path

  bucket=$(get_bucket "$env")
  prefix=$(get_prefix "$env")

  if [[ -z "$bucket" ]]; then
    echo -e "${RED}[ERROR]${NC} No backend.hcl found for environment: $env"
    return 1
  fi

  if [[ ! -f "$tfvars_file" ]]; then
    echo -e "${YELLOW}[SKIP]${NC} No terraform.tfvars found for environment: $env"
    return 0
  fi

  gcs_path="gs://${bucket}/${prefix}/terraform.tfvars"

  echo -e "${GREEN}[UPLOAD]${NC} envs/$env/terraform.tfvars -> $gcs_path"
  gcloud storage cp "$tfvars_file" "$gcs_path"
}

# Download tfvars from GCS
download_tfvars() {
  local env="$1"
  local tfvars_file="$ENVS_DIR/$env/terraform.tfvars"
  local bucket prefix gcs_path

  bucket=$(get_bucket "$env")
  prefix=$(get_prefix "$env")

  if [[ -z "$bucket" ]]; then
    echo -e "${RED}[ERROR]${NC} No backend.hcl found for environment: $env"
    return 1
  fi

  gcs_path="gs://${bucket}/${prefix}/terraform.tfvars"

  # Check if file exists in GCS
  if ! gcloud storage objects describe "$gcs_path" 2>/dev/null; then
    echo -e "${YELLOW}[SKIP]${NC} No terraform.tfvars in GCS for environment: $env"
    return 0
  fi

  echo -e "${GREEN}[DOWNLOAD]${NC} $gcs_path -> envs/$env/terraform.tfvars"
  gcloud storage cp "$gcs_path" "$tfvars_file"
}

# Get list of environments (compatible with macOS and Linux)
get_environments() {
  for dir in "$ENVS_DIR"/*/; do
    [[ -d "$dir" ]] && basename "$dir"
  done | sort
}

# Main logic
main() {
  local envs=()

  # Determine which environments to process
  if [[ -n "$TARGET_ENV" ]]; then
    if [[ ! -d "$ENVS_DIR/$TARGET_ENV" ]]; then
      echo -e "${RED}[ERROR]${NC} Environment not found: $TARGET_ENV"
      echo ""
      echo "Available environments:"
      get_environments
      exit 1
    fi
    envs=("$TARGET_ENV")
  else
    # Read environments into array (compatible with Bash 3.x on macOS)
    while IFS= read -r env; do
      [[ -n "$env" ]] && envs+=("$env")
    done < <(get_environments)
  fi

  if [[ ${#envs[@]} -eq 0 ]]; then
    echo -e "${RED}[ERROR]${NC} No environments found in $ENVS_DIR"
    exit 1
  fi

  # Convert action to uppercase (compatible with Bash 3.x)
  local action_upper
  action_upper=$(echo "$ACTION" | tr '[:lower:]' '[:upper:]')

  echo "========================================"
  echo "Terraform tfvars Sync - ${action_upper}"
  echo "========================================"
  echo ""

  local success=0
  local failed=0

  for env in "${envs[@]}"; do
    if [[ "$ACTION" == "upload" ]]; then
      if upload_tfvars "$env"; then
        ((success++))
      else
        ((failed++))
      fi
    else
      if download_tfvars "$env"; then
        ((success++))
      else
        ((failed++))
      fi
    fi
  done

  echo ""
  echo "----------------------------------------"
  echo -e "Completed: ${GREEN}${success}${NC} success, ${RED}${failed}${NC} failed"

  if [[ $failed -gt 0 ]]; then
    exit 1
  fi
}

main
