#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT/containers/apptainer/mir-common.def.in"
ENV_FILE="$ROOT/repos/mir-environment/environment-apptainer.yml"
MIR_CORE_DIR="$ROOT/repos/mir-core"
BUILD_OPTS="${APPTAINER_BUILD_OPTS:-}"

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

OUTPUT_IMAGE="${1:-${APPTAINER_IMAGE:-$ROOT/containers/apptainer/mir-common.sif}}"

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

if [[ -n "$BUILD_OPTS" ]]; then
  # shellcheck disable=SC2086
  apptainer build $BUILD_OPTS "$OUTPUT_IMAGE" "$TMP_DEF"
else
  apptainer build "$OUTPUT_IMAGE" "$TMP_DEF"
fi
