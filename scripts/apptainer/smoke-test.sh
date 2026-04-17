#!/usr/bin/env bash
# smoke-test.sh [--no-nv] [--verbose]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
USE_NV="yes"
VERBOSE="no"

pass() {
  printf 'PASS: %s\n' "$1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-nv)
      USE_NV="no"
      ;;
    --verbose|-v)
      VERBOSE="yes"
      ;;
    *)
      echo "Usage: $0 [--no-nv] [--verbose]"
      exit 1
      ;;
  esac
  shift
done

if [[ ! -f "$ROOT/.env" ]]; then
  echo "Missing $ROOT/.env"
  echo "Run ./scripts/workspace/init-workspace.sh first."
  exit 1
fi
pass ".env exists"

if ! command -v apptainer >/dev/null 2>&1; then
  echo "apptainer is not available on PATH."
  exit 1
fi
pass "apptainer on PATH"

# shellcheck disable=SC1091
source "$ROOT/scripts/lib/env.sh"
load_workspace_env "$ROOT"

IMAGE="${APPTAINER_IMAGE:-$ROOT/${APPTAINER_DVC_IMAGE:-containers/apptainer/images/mir-common.sif}}"

if [[ ! -f "$IMAGE" ]]; then
  echo "Missing Apptainer image: $IMAGE"
  echo "Build or copy the shared image first."
  exit 1
fi
pass "Apptainer image exists"

if [[ "$VERBOSE" == "yes" ]]; then
  echo
  echo "==> Host"
  echo "hostname=$(hostname)"
  echo "kernel=$(uname -srmo)"
  echo "cpu=$(lscpu | awk -F: '/Model name/ {sub(/^[ \t]+/, \"\", $2); print $2; exit}' 2>/dev/null || echo unknown)"
  echo "cpus=$(nproc 2>/dev/null || echo unknown)"
  if command -v free >/dev/null 2>&1; then
    free -h
  fi
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader || true
  else
    echo "nvidia-smi=missing"
  fi
fi

echo
echo "==> Apptainer Image"
echo "image=$IMAGE"
if [[ "$VERBOSE" == "yes" ]]; then
  du -h "$IMAGE" | awk '{ print "image_size=" $1 }'
fi
apptainer --version

echo
echo "==> Runtime Verification"
if [[ "$USE_NV" == "yes" ]]; then
  export MIR_SMOKE_VERBOSE="$VERBOSE"
  "$ROOT/scripts/apptainer/exec.sh" python - <<'PY'
import importlib
import os
import platform
import shutil
import subprocess

modules = ["torch", "torchaudio", "librosa", "mir_eval", "mirdata", "madmom", "mir_core"]
for name in modules:
    module = importlib.import_module(name)
    version = getattr(module, "__version__", "unknown")
    print(f"PASS: import {name} ({version})")

import torch
print(f"container_python={platform.python_version()}")
print(f"torch_version={torch.__version__}")
print(f"torch_cuda_build={torch.version.cuda}")
print(f"cuda_available={torch.cuda.is_available()}")
print(f"cuda_device_count={torch.cuda.device_count()}")
if os.environ.get("MIR_SMOKE_VERBOSE") == "yes":
    print(f"container_executable={os.sys.executable}")
    for idx in range(torch.cuda.device_count()):
        props = torch.cuda.get_device_properties(idx)
        print(f"cuda_device_{idx}={props.name}, memory={props.total_memory // (1024**2)} MiB")
    if shutil.which("nvidia-smi"):
        subprocess.run(["nvidia-smi"], check=False)
    else:
        print("container_nvidia_smi=missing")
PY
else
  export MIR_SMOKE_VERBOSE="$VERBOSE"
  "$ROOT/scripts/apptainer/exec.sh" --no-nv python - <<'PY'
import importlib
import os
import platform

modules = ["torch", "torchaudio", "librosa", "mir_eval", "mirdata", "madmom", "mir_core"]
for name in modules:
    module = importlib.import_module(name)
    version = getattr(module, "__version__", "unknown")
    print(f"PASS: import {name} ({version})")

import torch
print(f"container_python={platform.python_version()}")
print(f"torch_version={torch.__version__}")
print(f"torch_cuda_build={torch.version.cuda}")
print(f"cuda_available={torch.cuda.is_available()}")
if os.environ.get("MIR_SMOKE_VERBOSE") == "yes":
    print(f"container_executable={os.sys.executable}")
PY
fi

echo
pass "Apptainer smoke test"
