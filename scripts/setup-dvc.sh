#!/usr/bin/env bash
set -euo pipefail

workspace_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$workspace_root/.env"

get_env_value() {
  local key="$1"
  local file="$2"
  awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, "", $0); print $0; exit}' "$file"
}

set_env_value() {
  local key="$1"
  local value="$2"
  local file="$3"
  if grep -q "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

prompt_env_value() {
  local key="$1"
  local label="$2"
  local current_value
  local input_value

  current_value="$(get_env_value "$key" "$env_file")"
  read -r -p "$label [$current_value]: " input_value
  if [[ -n "$input_value" ]]; then
    set_env_value "$key" "$input_value" "$env_file"
  fi
}

if [[ ! -f "$env_file" ]]; then
  echo "Missing $env_file"
  exit 1
fi

echo "==> MinIO / DVC credentials..."
prompt_env_value "AWS_ACCESS_KEY_ID" "MinIO access key"
prompt_env_value "AWS_SECRET_ACCESS_KEY" "MinIO secret key"

set -a
source "$env_file"
set +a

: "${MINIO_ENDPOINT:?MINIO_ENDPOINT missing from .env}"

if [[ "$AWS_ACCESS_KEY_ID" == "your-minio-access-key" ]] || [[ "$AWS_SECRET_ACCESS_KEY" == "your-minio-secret-key" ]]; then
  echo "Skipping DVC remote setup"
  echo "  .env still contains placeholder MinIO credentials"
  echo "  Update $env_file and rerun $0 when ready"
  exit 0
fi

configure_remote() {
  local repo_dir="$1"
  local bucket="$2"

  if [[ ! -d "$repo_dir/.dvc" ]]; then
    echo "Missing DVC repo: $repo_dir"
    exit 1
  fi

  echo "==> $(basename "$repo_dir")"
  (
    cd "$repo_dir"
    dvc remote add -f -d origin "s3://$bucket"
    dvc remote modify origin endpointurl "$MINIO_ENDPOINT"
    dvc remote modify --local origin access_key_id "$AWS_ACCESS_KEY_ID"
    dvc remote modify --local origin secret_access_key "$AWS_SECRET_ACCESS_KEY"
    dvc remote list
  )
  echo
}

configure_remote "$workspace_root/repos/mir-data" "mir-data"
configure_remote "$workspace_root/repos/mir-outputs" "mir-outputs"

echo "DVC remotes configured. Credentials were written to .dvc/config.local files, which are ignored by Git."

read -r -p "Pull mir-data DVC data now? [y/N]: " pull_now
case "$pull_now" in
  y|Y|yes|YES)
    echo "==> Pulling mir-data data..."
    (
      cd "$workspace_root/repos/mir-data"
      dvc pull
    )
    ;;
  *)
    ;;
esac
