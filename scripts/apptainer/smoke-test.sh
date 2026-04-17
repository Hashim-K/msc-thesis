#!/usr/bin/env bash
# smoke-test-apptainer.sh [--no-nv]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
USE_NV="yes"

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [--no-nv]"
  exit 1
fi

if [[ "${1:-}" == "--no-nv" ]]; then
  USE_NV="no"
fi

if [[ ! -f "$ROOT/.env" ]]; then
  echo "Missing $ROOT/.env"
  echo "Run ./scripts/workspace/init-workspace.sh first."
  exit 1
fi

if ! command -v apptainer >/dev/null 2>&1; then
  echo "apptainer is not available on PATH."
  exit 1
fi

# shellcheck disable=SC1091
source "$ROOT/scripts/lib/env.sh"
load_env_file "$ROOT/.env"

IMAGE="${APPTAINER_IMAGE:-$ROOT/${APPTAINER_DVC_IMAGE:-containers/apptainer/images/mir-common.sif}}"

if [[ ! -f "$IMAGE" ]]; then
  echo "Missing Apptainer image: $IMAGE"
  echo "Build or copy the shared image first."
  exit 1
fi

echo "==> Apptainer image"
echo "image=$IMAGE"
apptainer --version

echo
echo "==> Runtime verification"
if [[ "$USE_NV" == "yes" ]]; then
  "$ROOT/scripts/apptainer/exec.sh" python - <<'PY'
import importlib
modules = ["torch", "torchaudio", "librosa", "mir_eval", "mirdata", "madmom", "mir_core"]
for name in modules:
    importlib.import_module(name)
print("imports=ok")
import torch
print(f"torch_version={torch.__version__}")
print(f"cuda_available={torch.cuda.is_available()}")
PY
else
  "$ROOT/scripts/apptainer/exec.sh" --no-nv python - <<'PY'
import importlib
modules = ["torch", "torchaudio", "librosa", "mir_eval", "mirdata", "madmom", "mir_core"]
for name in modules:
    importlib.import_module(name)
print("imports=ok")
PY
fi

echo
echo "Apptainer smoke test passed."
