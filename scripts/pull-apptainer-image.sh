#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVFILE="$ROOT/.env"

if [[ ! -f "$ENVFILE" ]]; then
  echo "Missing $ENVFILE"
  echo "Run ./scripts/init-workspace.sh first."
  exit 1
fi

set -a
# shellcheck disable=SC1091
source "$ENVFILE"
set +a

: "${MINIO_ENDPOINT:?MINIO_ENDPOINT missing from .env}"
: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID missing from .env}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY missing from .env}"

IMAGE_REL="${APPTAINER_DVC_IMAGE:-containers/apptainer/images/mir-common.sif}"
IMAGE_PATH="$ROOT/$IMAGE_REL"
DEPLOY_IMAGE="${APPTAINER_IMAGE:-$IMAGE_PATH}"

(
  cd "$ROOT"
  dvc remote add -f -d origin s3://mir-containers
  dvc remote modify origin endpointurl "$MINIO_ENDPOINT"
  dvc remote modify --local origin access_key_id "$AWS_ACCESS_KEY_ID"
  dvc remote modify --local origin secret_access_key "$AWS_SECRET_ACCESS_KEY"
  dvc pull "$IMAGE_REL.dvc"
)

if [[ "$DEPLOY_IMAGE" != "$IMAGE_PATH" ]]; then
  mkdir -p "$(dirname "$DEPLOY_IMAGE")"
  ln -sfn "$IMAGE_PATH" "$DEPLOY_IMAGE"
  echo "Linked $DEPLOY_IMAGE -> $IMAGE_PATH"
fi

echo "Apptainer image ready: $DEPLOY_IMAGE"
