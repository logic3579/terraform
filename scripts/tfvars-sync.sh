#!/bin/bash
# Sync env files between an env directory and S3-compatible object storage
# (AWS S3 or Cloudflare R2). GCS support has been removed.
#
# Remote object key is fixed by convention:
#   s3://<bucket>/<platform>/<env>/<file>
#
# Credentials come from env vars (S3_ACCESS_KEY / S3_SECRET_ACCESS_KEY):
#   --storage r2 : required
#   --storage s3 : optional — falls back to the AWS default credential chain
#                  (AWS_PROFILE / AWS_ACCESS_KEY_ID / IMDS) when unset

set -euo pipefail

# ---- color ---------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# ---- globals -------------------------------------------------------------
ACTION=""
PLATFORM=""
ENV=""
STORAGE=""
FILE="terraform.tfvars"
BUCKET="terraform-state"
ENDPOINT=""
DRY_RUN=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ---- usage ---------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") <upload|download> --platform NAME --storage <s3|r2> [options]

Required:
  upload | download              direction
  --platform NAME                aws | gcp | proxmox | openstack | vultr
  --storage  NAME                s3 | r2

Options:
  --env      NAME                specific env (e.g. dev, logic3579); omit for all envs of the platform
  --file     FILE                filename inside the env dir to sync (default: terraform.tfvars)
                                 e.g. terraform.tfstate, terraform.tfvars.json
  --bucket   NAME                bucket name (default: terraform-state)
  --endpoint URL                 S3 endpoint URL. Required for --storage r2; optional for --storage s3.
                                 e.g. https://<account>.r2.cloudflarestorage.com
  --dry-run                      print the planned cp command(s) without executing
  -h, --help                     show this help

Remote object key (always):
  s3://<bucket>/<platform>/<env>/<file>

Credentials (env vars, never CLI flags):
  S3_ACCESS_KEY         r2: required.  s3: optional (falls back to AWS default chain)
  S3_SECRET_ACCESS_KEY  r2: required.  s3: optional (falls back to AWS default chain)

Examples:
  # Back up vultr local state + tfvars to R2
  export S3_ACCESS_KEY=...   S3_SECRET_ACCESS_KEY=...
  $(basename "$0") upload --platform vultr --env logic3579 --storage r2 \\
      --file terraform.tfstate --endpoint https://<account>.r2.cloudflarestorage.com
  $(basename "$0") upload --platform vultr --env logic3579 --storage r2 \\
      --file terraform.tfvars  --endpoint https://<account>.r2.cloudflarestorage.com

  # Upload one aws env tfvars to AWS S3 (uses AWS default credential chain)
  $(basename "$0") upload --platform aws --storage s3 --env dev --bucket my-tfstate

  # Download all proxmox envs from R2
  $(basename "$0") download --platform proxmox --storage r2 \\
      --endpoint https://<account>.r2.cloudflarestorage.com

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
      --file)     FILE="${2:-}";     shift 2 ;;
      --bucket)   BUCKET="${2:-}";   shift 2 ;;
      --endpoint) ENDPOINT="${2:-}"; shift 2 ;;
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

  if [[ -z "$FILE" ]]; then
    echo -e "${RED}[ERROR]${NC} --file must not be empty"
    usage
  fi

  if [[ -z "$BUCKET" ]]; then
    echo -e "${RED}[ERROR]${NC} --bucket must not be empty"
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

  if [[ ! "$STORAGE" =~ ^(s3|r2)$ ]]; then
    echo -e "${RED}[ERROR]${NC} --storage must be one of: s3, r2 (got: '$STORAGE')"
    usage
  fi

  if [[ "$STORAGE" == "r2" && -z "$ENDPOINT" ]]; then
    echo -e "${RED}[ERROR]${NC} --endpoint is required when --storage r2"
    usage
  fi
}

# ---- remote URI ---------------------------------------------------------
compute_remote_uri() {
  local env="$1" filename="$2"
  echo "s3://${BUCKET}/${PLATFORM}/${env}/${filename}"
}

# ---- cp runner ----------------------------------------------------------
run_cp() {
  local src="$1" dst="$2"
  local endpoint_arg=() region_arg=()

  [[ -n "$ENDPOINT" ]] && endpoint_arg=(--endpoint-url="$ENDPOINT")

  case "$STORAGE" in
    r2)
      # R2 only accepts canonical region names (wnam/enam/weur/eeur/apac/oc/auto).
      # Force --region auto so the local AWS profile's region doesn't leak through.
      region_arg=(--region auto)

      if [[ -z "${S3_ACCESS_KEY:-}" || -z "${S3_SECRET_ACCESS_KEY:-}" ]]; then
        echo -e "  ${RED}[ERROR]${NC} S3_ACCESS_KEY and S3_SECRET_ACCESS_KEY env vars are required for --storage r2"
        return 1
      fi

      if $DRY_RUN; then
        echo -e "  ${CYAN}[DRY-RUN]${NC} AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY:0:6}… AWS_SECRET_ACCESS_KEY=… \\"
        echo -e "                aws s3 cp ${region_arg[*]} ${endpoint_arg[*]} \"$src\" \"$dst\""
      else
        AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY" \
          aws s3 cp "${region_arg[@]}" "${endpoint_arg[@]}" "$src" "$dst"
      fi
      ;;

    s3)
      # If S3_ACCESS_KEY/SECRET are set, use them; otherwise fall back to the
      # AWS default credential chain (AWS_PROFILE, ~/.aws/credentials, IMDS, etc).
      if [[ -n "${S3_ACCESS_KEY:-}" && -n "${S3_SECRET_ACCESS_KEY:-}" ]]; then
        if $DRY_RUN; then
          echo -e "  ${CYAN}[DRY-RUN]${NC} AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY:0:6}… AWS_SECRET_ACCESS_KEY=… \\"
          echo -e "                aws s3 cp ${endpoint_arg[*]:-} \"$src\" \"$dst\""
        else
          AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY" \
            aws s3 cp "${endpoint_arg[@]}" "$src" "$dst"
        fi
      else
        if $DRY_RUN; then
          echo -e "  ${CYAN}[DRY-RUN]${NC} aws s3 cp ${endpoint_arg[*]:-} \"$src\" \"$dst\""
        else
          aws s3 cp "${endpoint_arg[@]}" "$src" "$dst"
        fi
      fi
      ;;
  esac
}

# ---- per-env worker -----------------------------------------------------
process_env() {
  local env="$1"
  local env_dir="$PROJECT_ROOT/$PLATFORM/envs/$env"
  local local_file="$env_dir/$FILE"
  local rel_local="$PLATFORM/envs/$env/$FILE"

  local remote_uri
  remote_uri=$(compute_remote_uri "$env" "$FILE")

  if [[ "$ACTION" == "upload" ]]; then
    if [[ ! -f "$local_file" ]]; then
      echo -e "${YELLOW}[SKIP]${NC} $env: no $FILE to upload"
      return 0
    fi
    echo -e "${GREEN}[UPLOAD]${NC} $env: $rel_local → $remote_uri"
    run_cp "$local_file" "$remote_uri"
  else
    echo -e "${GREEN}[DOWNLOAD]${NC} $env: $remote_uri → $rel_local"
    run_cp "$remote_uri" "$local_file"
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
  echo -e "tfvars sync — ${action_upper}  ${PLATFORM} ⇄ ${STORAGE}  bucket=${BUCKET}  file=${FILE}${dry_marker}"
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
