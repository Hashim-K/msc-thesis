#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE="$ROOT/containers/apptainer/mir-common.def.in"
ENV_FILE="$ROOT/repos/mir-environment/environment-apptainer.yml"
MIR_CORE_DIR="$ROOT/repos/mir-core"
REQUESTED_BUILD_IMAGE="${APPTAINER_BUILD_IMAGE:-}"
REQUESTED_BUILD_OPTS="${APPTAINER_BUILD_OPTS:-}"
REQUESTED_MKSQUASHFS_ARGS="${APPTAINER_MKSQUASHFS_ARGS:-}"

# shellcheck disable=SC1091
source "$ROOT/scripts/lib/env.sh"
load_workspace_env "$ROOT"

DEFAULT_IMAGE_REL="${APPTAINER_DVC_IMAGE:-containers/apptainer/images/mir-common.sif}"
BUILD_OPTS="${REQUESTED_BUILD_OPTS:-${APPTAINER_BUILD_OPTS:-}}"
MKSQUASHFS_ARGS="${REQUESTED_MKSQUASHFS_ARGS:-${APPTAINER_MKSQUASHFS_ARGS:-}}"
OUTPUT_IMAGE="${1:-${REQUESTED_BUILD_IMAGE:-${APPTAINER_BUILD_IMAGE:-$ROOT/$DEFAULT_IMAGE_REL}}}"

if ! command -v apptainer >/dev/null 2>&1; then
  echo "apptainer is not available on PATH."
  exit 1
fi

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Missing template: $TEMPLATE"
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing environment file: $ENV_FILE"
  exit 1
fi

if [[ ! -d "$MIR_CORE_DIR" ]]; then
  echo "Missing mir-core checkout: $MIR_CORE_DIR"
  exit 1
fi

TMP_DEF="$(mktemp)"
trap 'rm -f "$TMP_DEF"' EXIT

sed \
  -e "s|__ENV_FILE__|$ENV_FILE|g" \
  -e "s|__MIR_CORE__|$MIR_CORE_DIR|g" \
  "$TEMPLATE" > "$TMP_DEF"

mkdir -p "$(dirname "$OUTPUT_IMAGE")"

echo "==> Building Apptainer image"
echo "    Template: $TEMPLATE"
echo "    Env file: $ENV_FILE"
echo "    mir-core: $MIR_CORE_DIR"
echo "    Output:   $OUTPUT_IMAGE"
if [[ -n "$BUILD_OPTS" ]]; then
  echo "    Build options: $BUILD_OPTS"
fi
if [[ -n "$MKSQUASHFS_ARGS" ]]; then
  echo "    mksquashfs args: $MKSQUASHFS_ARGS"
fi

args=(build)
if [[ -n "$BUILD_OPTS" ]]; then
  # Legacy convenience for simple flags such as "--force --fakeroot".
  # Use APPTAINER_MKSQUASHFS_ARGS for options that need a quoted value.
  read -r -a extra_build_opts <<< "$BUILD_OPTS"
  args+=("${extra_build_opts[@]}")
fi
if [[ -n "$MKSQUASHFS_ARGS" ]]; then
  args+=(--mksquashfs-args "$MKSQUASHFS_ARGS")
fi
args+=("$OUTPUT_IMAGE" "$TMP_DEF")

apptainer "${args[@]}"
