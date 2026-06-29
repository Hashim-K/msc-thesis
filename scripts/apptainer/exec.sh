#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
USE_NV="yes"
REQUESTED_APPTAINER_IMAGE="${APPTAINER_IMAGE:-}"
REQUESTED_IMAGE="${IMAGE:-}"

find_apptainer() {
  local candidate

  if [[ -n "${APPTAINER_BIN:-}" && -x "${APPTAINER_BIN:-}" ]]; then
    printf '%s\n' "$APPTAINER_BIN"
    return 0
  fi

  if command -v apptainer >/dev/null 2>&1; then
    command -v apptainer
    return 0
  fi

  for candidate in \
    "$HOME/miniforge3/envs/apptainer-runtime/bin/apptainer" \
    "$HOME/miniforge3/envs/MIR/bin/apptainer" \
    "$HOME/miniconda3/envs/apptainer-runtime/bin/apptainer" \
    "$HOME/miniconda3/envs/MIR/bin/apptainer"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

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

if ! APPTAINER_CMD="$(find_apptainer)"; then
  echo "apptainer is not available on PATH or in a known local conda runtime."
  exit 1
fi
PATH="$(dirname "$APPTAINER_CMD"):$PATH"
export PATH

# shellcheck disable=SC1091
source "$ROOT/scripts/lib/env.sh"
load_workspace_env "$ROOT"

IMAGE="${REQUESTED_APPTAINER_IMAGE:-${REQUESTED_IMAGE:-${APPTAINER_IMAGE:-${IMAGE:-$ROOT/${APPTAINER_DVC_IMAGE:-containers/apptainer/images/mir-common.sif}}}}}"

if [[ ! -f "$IMAGE" ]]; then
  echo "Missing Apptainer image: $IMAGE"
  echo "Build it first with: $ROOT/scripts/apptainer/build.sh"
  exit 1
fi

binds=("$ROOT:$ROOT")

add_bind_if_set() {
  local value="$1"
  [[ -n "$value" && -e "$value" ]] || return 0
  binds+=("$value:$value")
}

add_bind_if_set "${MIR_DATA_ROOT:-}"
add_bind_if_set "${MIR_OUTPUTS_ROOT:-}"
add_bind_if_set "${MIR_CORE_PATH:-}"
add_bind_if_set "${MIR_SHARED_ROOT:-}"
add_bind_if_set "${MIR_RUNS_ROOT:-}"

args=(exec)
if [[ "$USE_NV" == "yes" ]]; then
  args+=(--nv)
fi

for bind in "${binds[@]}"; do
  args+=(--bind "$bind")
done

args+=("$IMAGE")
args+=("$@")

exec "$APPTAINER_CMD" "${args[@]}"
