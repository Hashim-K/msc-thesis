#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENVFILE="$ROOT/.env"

if [[ ! -f "$ENVFILE" ]]; then
  echo "Missing $ENVFILE"
  echo "Run ./scripts/workspace/init.sh first."
  exit 1
fi

# shellcheck disable=SC1091
source "$ROOT/scripts/lib/env.sh"
load_workspace_env "$ROOT"

: "${MINIO_ENDPOINT:?MINIO_ENDPOINT missing from .env}"
: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID missing from .env}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY missing from .env}"
: "${MIR_SHARED_ROOT:?MIR_SHARED_ROOT missing from .env}"

IMAGE_REL="${APPTAINER_DVC_IMAGE:-containers/apptainer/images/mir-common.sif}"
IMAGE_PATH="$ROOT/$IMAGE_REL"
DEPLOY_IMAGE="${APPTAINER_IMAGE:-$IMAGE_PATH}"
SHARED_CACHE_DIR="$MIR_SHARED_ROOT/dvc-cache"
DEPLOY_IMAGE_DIR="$(dirname "$DEPLOY_IMAGE")"

echo "==> Apptainer image pull paths"
printf '    env_files=%q\n' "${MIR_ENV_LOADED_FILES:-}"
printf '    MIR_ENV_PROFILE=%q\n' "${MIR_ENV_PROFILE:-}"
printf '    MIR_SHARED_ROOT=%q\n' "$MIR_SHARED_ROOT"
printf '    SHARED_CACHE_DIR=%q\n' "$SHARED_CACHE_DIR"
printf '    IMAGE_PATH=%q\n' "$IMAGE_PATH"
printf '    DEPLOY_IMAGE=%q\n' "$DEPLOY_IMAGE"

if ! command -v dvc >/dev/null 2>&1; then
  case "${MIR_ENV_PROFILE:-}" in
    daic)
      echo "==> dvc not found; loading DAIC host-tools environment..."
      # shellcheck disable=SC1091
      source "$ROOT/scripts/daic/env.sh"
      ;;
  esac
fi

if ! command -v dvc >/dev/null 2>&1; then
  echo "dvc is not available on PATH."
  echo "Activate the host-tools environment first:"
  echo "  conda activate MIR-hpc"
  echo "On DAIC, if conda is not loaded yet:"
  echo "  source ./scripts/daic/env.sh"
  exit 1
fi

ensure_dir() {
  local path="$1"
  local label="$2"

  if [[ -d "$path" ]]; then
    return
  fi

  if ! mkdir -p "$path"; then
    echo "Failed to create $label: $path"
    echo "Parent directory:"
    ls -ld "$(dirname "$path")" 2>/dev/null || true
    exit 1
  fi
}

ensure_dir "$SHARED_CACHE_DIR" "shared DVC cache"
ensure_dir "$DEPLOY_IMAGE_DIR" "Apptainer image directory"

(
  cd "$ROOT"
  dvc remote add -f -d origin s3://mir-containers
  dvc remote modify origin endpointurl "$MINIO_ENDPOINT"
  dvc remote modify --local origin access_key_id "$AWS_ACCESS_KEY_ID"
  dvc remote modify --local origin secret_access_key "$AWS_SECRET_ACCESS_KEY"
  dvc config --local cache.dir "$SHARED_CACHE_DIR"
  dvc config --local cache.type symlink
  dvc pull "$IMAGE_REL.dvc"
)

if [[ "$DEPLOY_IMAGE" != "$IMAGE_PATH" ]]; then
  ln -sfn "$IMAGE_PATH" "$DEPLOY_IMAGE"
  echo "Linked $DEPLOY_IMAGE -> $IMAGE_PATH"
fi

echo "Apptainer image ready: $DEPLOY_IMAGE"
