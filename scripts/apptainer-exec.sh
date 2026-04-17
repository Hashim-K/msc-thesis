#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USE_NV="yes"

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 [--no-nv] <command> [args...]"
  exit 1
fi

if [[ "$1" == "--no-nv" ]]; then
  USE_NV="no"
  shift
fi

if [[ ! -f "$ROOT/.env" ]]; then
  echo "Missing $ROOT/.env"
  exit 1
fi

if ! command -v apptainer >/dev/null 2>&1; then
  echo "apptainer is not available on PATH."
  exit 1
fi

# shellcheck disable=SC1091
source "$ROOT/scripts/lib/env.sh"
load_env_file "$ROOT/.env"

IMAGE="${APPTAINER_IMAGE:-${IMAGE:-$ROOT/containers/apptainer/mir-common.sif}}"

if [[ ! -f "$IMAGE" ]]; then
  echo "Missing Apptainer image: $IMAGE"
  echo "Build it first with: $ROOT/scripts/build-apptainer.sh"
  exit 1
fi

binds=(
  "$ROOT:$ROOT"
  "$MIR_DATA_ROOT:$MIR_DATA_ROOT"
  "$MIR_OUTPUTS_ROOT:$MIR_OUTPUTS_ROOT"
  "$MIR_CORE_PATH:$MIR_CORE_PATH"
  "$MIR_SHARED_ROOT:$MIR_SHARED_ROOT"
  "$MIR_RUNS_ROOT:$MIR_RUNS_ROOT"
)

args=(exec)
if [[ "$USE_NV" == "yes" ]]; then
  args+=(--nv)
fi

for bind in "${binds[@]}"; do
  args+=(--bind "$bind")
done

args+=("$IMAGE")
args+=("$@")

exec apptainer "${args[@]}"
