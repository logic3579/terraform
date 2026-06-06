#!/bin/bash
# Sync terraform.tfvars between an env directory and remote object storage.
#
# Picks the right storage backend (GCS / S3 / Cloudflare R2) based on flags,
# and derives the remote URI from the env's backend.hcl:
#   gcs : gs://<bucket>/<prefix>/terraform.tfvars
#   s3  : s3://<bucket>/<dirname(key)>/terraform.tfvars  (default AWS creds)
#   r2  : s3://<bucket>/<dirname(key)>/terraform.tfvars  with --endpoint-url +
#         access_key/secret_key sourced from backend.hcl

set -euo pipefail

# ---- color ---------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# ---- globals -------------------------------------------------------------
ACTION=""
PLATFORM=""
ENV=""
STORAGE=""
DRY_RUN=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ---- usage ---------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") <upload|download> --platform <name> --storage <name> [--env <name>] [--dry-run]

Arguments:
  upload | download              direction
  --platform NAME                aws | gcp | proxmox | openstack
  --storage  NAME                gcs | s3 | r2
  --env      NAME                specific env (e.g. dev, logic3579); omit for all envs of the platform
  --dry-run                      print the planned cp command(s) without executing
  -h, --help                     show this help

Examples:
  # Download all gcp envs from GCS
  $(basename "$0") download --platform gcp --storage gcs

  # Upload one aws env to Cloudflare R2 (creds read from its backend.hcl)
  $(basename "$0") upload --platform aws --storage r2 --env logic3579

  # Preview without executing
  $(basename "$0") upload --platform aws --storage s3 --env dev --dry-run
EOF
  exit 1
}

# ---- arg parsing ---------------------------------------------------------
parse_args() {
  if [[ $# -lt 1 ]]; then usage; fi
  ACTION="$1"; shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --platform) PLATFORM="${2:-}"; shift 2 ;;
      --env)      ENV="${2:-}";      shift 2 ;;
      --storage)  STORAGE="${2:-}";  shift 2 ;;
      --dry-run)  DRY_RUN=true;      shift ;;
      -h|--help)  usage ;;
      *)
        echo -e "${RED}[ERROR]${NC} Unknown argument: $1"
        usage
        ;;
    esac
  done

  if [[ ! "$ACTION" =~ ^(upload|download)$ ]]; then
    echo -e "${RED}[ERROR]${NC} action must be 'upload' or 'download' (got: '$ACTION')"
    usage
  fi

  if [[ -z "$PLATFORM" ]]; then
    echo -e "${RED}[ERROR]${NC} --platform is required"
    usage
  fi

  if [[ ! -d "$PROJECT_ROOT/$PLATFORM/envs" ]]; then
    echo -e "${RED}[ERROR]${NC} platform '$PLATFORM' has no envs/ directory under $PROJECT_ROOT/$PLATFORM/envs"
    exit 1
  fi

  if [[ -z "$STORAGE" ]]; then
    echo -e "${RED}[ERROR]${NC} --storage is required"
    usage
  fi

  if [[ ! "$STORAGE" =~ ^(gcs|s3|r2)$ ]]; then
    echo -e "${RED}[ERROR]${NC} --storage must be one of: gcs, s3, r2 (got: '$STORAGE')"
    usage
  fi
}

# ---- backend.hcl parsing -------------------------------------------------
# Top-level key = "value"
get_backend_value() {
  local file="$1" key="$2"
  grep -E "^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"" "$file" 2>/dev/null \
    | head -1 \
    | sed -E 's/^[^"]*"([^"]*)".*$/\1/'
}

# endpoints.s3 (handles both inline { s3 = "..." } and multi-line block form)
get_endpoint_s3() {
  local file="$1"
  awk '
    /endpoints[[:space:]]*=/        { in_block=1 }
    in_block && /s3[[:space:]]*=[[:space:]]*"/ {
      sub(/^[^"]*"/, "")
      sub(/".*/, "")
      print
      exit
    }
    in_block && /}/                 { in_block=0 }
  ' "$file"
}

# ---- remote URI ---------------------------------------------------------
compute_remote_uri() {
  local backend_file="$1" storage="$2"
  local bucket key prefix tfvars_key

  bucket=$(get_backend_value "$backend_file" "bucket")
  [[ -n "$bucket" ]] || return 1

  case "$storage" in
    gcs)
      prefix=$(get_backend_value "$backend_file" "prefix")
      [[ -n "$prefix" ]] || return 1
      echo "gs://${bucket}/${prefix}/terraform.tfvars"
      ;;
    s3|r2)
      key=$(get_backend_value "$backend_file" "key")
      [[ -n "$key" ]] || return 1
      tfvars_key="$(dirname "$key")/terraform.tfvars"
      echo "s3://${bucket}/${tfvars_key}"
      ;;
  esac
}

# ---- cp runner ----------------------------------------------------------
run_cp() {
  local backend_file="$1" src="$2" dst="$3" storage="$4"

  case "$storage" in
    gcs)
      if $DRY_RUN; then
        echo -e "  ${CYAN}[DRY-RUN]${NC} gcloud storage cp \"$src\" \"$dst\""
      else
        gcloud storage cp "$src" "$dst"
      fi
      ;;
    s3)
      if $DRY_RUN; then
        echo -e "  ${CYAN}[DRY-RUN]${NC} aws s3 cp \"$src\" \"$dst\""
      else
        aws s3 cp "$src" "$dst"
      fi
      ;;
    r2)
      local endpoint access_key secret_key
      endpoint=$(get_endpoint_s3 "$backend_file")
      access_key=$(get_backend_value "$backend_file" "access_key")
      secret_key=$(get_backend_value "$backend_file" "secret_key")

      if [[ -z "$endpoint" || -z "$access_key" || -z "$secret_key" ]]; then
        echo -e "  ${RED}[ERROR]${NC} R2 backend.hcl missing endpoints.s3 / access_key / secret_key"
        return 1
      fi

      # R2 only accepts region names: wnam | enam | weur | eeur | apac | oc | auto.
      # Pass --region auto explicitly so the local AWS profile's region (e.g. ap-southeast-1)
      # doesn't leak through and get rejected by the R2 API.
      if $DRY_RUN; then
        echo -e "  ${CYAN}[DRY-RUN]${NC} AWS_ACCESS_KEY_ID=${access_key:0:6}… AWS_SECRET_ACCESS_KEY=… \\"
        echo -e "                aws s3 cp --region auto --endpoint-url=\"$endpoint\" \"$src\" \"$dst\""
      else
        AWS_ACCESS_KEY_ID="$access_key" AWS_SECRET_ACCESS_KEY="$secret_key" \
          aws s3 cp --region auto --endpoint-url="$endpoint" "$src" "$dst"
      fi
      ;;
  esac
}

# ---- per-env worker -----------------------------------------------------
process_env() {
  local env="$1"
  local env_dir="$PROJECT_ROOT/$PLATFORM/envs/$env"
  local backend_file="$env_dir/backend.hcl"
  local tfvars_file="$env_dir/terraform.tfvars"
  local rel_tfvars="$PLATFORM/envs/$env/terraform.tfvars"

  if [[ ! -f "$backend_file" ]]; then
    echo -e "${RED}[ERROR]${NC} $env: no backend.hcl at $backend_file"
    return 1
  fi

  local remote_uri
  remote_uri=$(compute_remote_uri "$backend_file" "$STORAGE") || true
  if [[ -z "$remote_uri" ]]; then
    echo -e "${RED}[ERROR]${NC} $env: could not derive remote URI from backend.hcl (storage=$STORAGE)"
    return 1
  fi

  if [[ "$ACTION" == "upload" ]]; then
    if [[ ! -f "$tfvars_file" ]]; then
      echo -e "${YELLOW}[SKIP]${NC} $env: no terraform.tfvars to upload"
      return 0
    fi
    echo -e "${GREEN}[UPLOAD]${NC} $env: $rel_tfvars → $remote_uri"
    run_cp "$backend_file" "$tfvars_file" "$remote_uri" "$STORAGE"
  else
    echo -e "${GREEN}[DOWNLOAD]${NC} $env: $remote_uri → $rel_tfvars"
    run_cp "$backend_file" "$remote_uri" "$tfvars_file" "$STORAGE"
  fi
}

# ---- env discovery ------------------------------------------------------
list_envs() {
  local envs_dir="$PROJECT_ROOT/$PLATFORM/envs"
  for dir in "$envs_dir"/*/; do
    [[ -d "$dir" ]] && basename "$dir"
  done | sort
}

# ---- main ---------------------------------------------------------------
main() {
  parse_args "$@"

  local envs=()
  if [[ -n "$ENV" ]]; then
    if [[ ! -d "$PROJECT_ROOT/$PLATFORM/envs/$ENV" ]]; then
      echo -e "${RED}[ERROR]${NC} env not found: $PLATFORM/envs/$ENV"
      echo "Available:"
      list_envs
      exit 1
    fi
    envs=("$ENV")
  else
    while IFS= read -r e; do
      [[ -n "$e" ]] && envs+=("$e")
    done < <(list_envs)
  fi

  if [[ ${#envs[@]} -eq 0 ]]; then
    echo -e "${RED}[ERROR]${NC} no envs found in $PLATFORM/envs/"
    exit 1
  fi

  local action_upper
  action_upper=$(echo "$ACTION" | tr '[:lower:]' '[:upper:]')
  local dry_marker=""
  $DRY_RUN && dry_marker=" ${CYAN}[DRY-RUN]${NC}"

  echo "==================================================="
  echo -e "tfvars sync — ${action_upper}  ${PLATFORM} ⇄ ${STORAGE}${dry_marker}"
  echo "==================================================="
  echo

  local success=0 failed=0
  for env in "${envs[@]}"; do
    if process_env "$env"; then
      success=$((success + 1))
    else
      failed=$((failed + 1))
    fi
  done

  echo
  echo "---------------------------------------------------"
  echo -e "Completed: ${GREEN}${success}${NC} success, ${RED}${failed}${NC} failed"
  [[ $failed -eq 0 ]]
}

main "$@"
