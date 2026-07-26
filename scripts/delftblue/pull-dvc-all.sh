#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck disable=SC1091
source "$ROOT/scripts/delftblue/env.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/env.sh"
load_workspace_env "$ROOT"

echo "==> Env files: ${MIR_ENV_LOADED_FILES:-none}"
echo "==> MIR_ENV_PROFILE: ${MIR_ENV_PROFILE:-unset}"

: "${MINIO_ENDPOINT:?MINIO_ENDPOINT missing from .env}"
: "${MIR_SHARED_ROOT:?MIR_SHARED_ROOT missing from .env}"

SHARED_CACHE_DIR="$MIR_SHARED_ROOT/dvc-cache"
mkdir -p "$SHARED_CACHE_DIR" "${APPTAINER_CACHEDIR:-/scratch/$USER/.apptainer/cache}" "${TMPDIR:-/scratch/$USER/tmp}"

configure_remote() {
  local repo_dir="$1"
  local bucket="$2"

  echo "==> Configuring DVC remote for $repo_dir"
  (
    cd "$repo_dir"
    dvc remote add -f -d origin "s3://$bucket"
    dvc remote modify origin endpointurl "$MINIO_ENDPOINT"
    if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
      dvc remote modify --local origin access_key_id "$AWS_ACCESS_KEY_ID"
      dvc remote modify --local origin secret_access_key "$AWS_SECRET_ACCESS_KEY"
    else
      echo "==> AWS_* credentials are not in env; using existing DVC local config or credential provider"
    fi
    dvc config --local cache.dir "$SHARED_CACHE_DIR"
    dvc config --local cache.type symlink
  )
}

echo "==> Host: $(hostname)"
echo "==> Started: $(date -Is)"
echo "==> Root: $ROOT"
echo "==> Shell: $SHELL"
echo "==> PATH: $PATH"
echo "==> Shared DVC cache: $SHARED_CACHE_DIR"
echo "==> Apptainer cache: ${APPTAINER_CACHEDIR:-/scratch/$USER/.apptainer/cache}"
echo "==> TMPDIR: ${TMPDIR:-/scratch/$USER/tmp}"

echo "==> Pulling Apptainer image"
bash "$ROOT/scripts/apptainer/pull-image.sh"

configure_remote "$ROOT/repos/mir-data" "mir-data"
echo "==> Pulling all mir-data DVC outputs"
(cd "$ROOT/repos/mir-data" && dvc pull)

configure_remote "$ROOT/repos/mir-outputs" "mir-outputs"
echo "==> Pulling all mir-outputs DVC outputs"
(cd "$ROOT/repos/mir-outputs" && dvc pull)

echo "==> Finished: $(date -Is)"
