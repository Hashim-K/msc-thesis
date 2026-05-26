#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v module >/dev/null 2>&1; then
  for module_init in /usr/share/Modules/init/bash /etc/profile.d/modules.sh; do
    if [[ -f "$module_init" ]]; then
      # shellcheck disable=SC1090
      source "$module_init"
      break
    fi
  done
fi

# shellcheck disable=SC1091
source "$ROOT/scripts/daic/env.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/env.sh"
load_workspace_env "$ROOT"

: "${MINIO_ENDPOINT:?MINIO_ENDPOINT missing from .env}"
: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID missing from .env}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY missing from .env}"
: "${MIR_SHARED_ROOT:?MIR_SHARED_ROOT missing from .env}"

SHARED_CACHE_DIR="$MIR_SHARED_ROOT/dvc-cache"
mkdir -p "$SHARED_CACHE_DIR"

configure_remote() {
  local repo_dir="$1"
  local bucket="$2"

  echo "==> Configuring DVC remote for $repo_dir"
  (
    cd "$repo_dir"
    dvc remote add -f -d origin "s3://$bucket"
    dvc remote modify origin endpointurl "$MINIO_ENDPOINT"
    dvc remote modify --local origin access_key_id "$AWS_ACCESS_KEY_ID"
    dvc remote modify --local origin secret_access_key "$AWS_SECRET_ACCESS_KEY"
    dvc config --local cache.dir "$SHARED_CACHE_DIR"
    dvc config --local cache.type symlink
  )
}

echo "==> Host: $(hostname)"
echo "==> Started: $(date -Is)"
echo "==> Root: $ROOT"
echo "==> Shared DVC cache: $SHARED_CACHE_DIR"

echo "==> Pulling Apptainer image"
bash "$ROOT/scripts/apptainer/pull-image.sh"

configure_remote "$ROOT/repos/mir-data" "mir-data"
echo "==> Pulling all mir-data DVC outputs"
(cd "$ROOT/repos/mir-data" && dvc pull)

configure_remote "$ROOT/repos/mir-outputs" "mir-outputs"
echo "==> Pulling all mir-outputs DVC outputs"
(cd "$ROOT/repos/mir-outputs" && dvc pull)

echo "==> Finished: $(date -Is)"
