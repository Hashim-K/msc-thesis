#!/usr/bin/env bash
# smoke-test.sh [--no-nv] [--verbose]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
USE_NV="yes"
VERBOSE="no"
PASS_PREFIX="[PASS]"
WARN_PREFIX="[WARN]"
FAIL_PREFIX="[FAIL]"

if [[ -t 1 && -z "${NO_COLOR:-}" ]] || [[ -n "${FORCE_COLOR:-}" ]]; then
  PASS_PREFIX=$'\033[32m[PASS]\033[0m'
  WARN_PREFIX=$'\033[33m[WARN]\033[0m'
  FAIL_PREFIX=$'\033[31m[FAIL]\033[0m'
fi

export MIR_SMOKE_PASS_PREFIX="$PASS_PREFIX"
export MIR_SMOKE_WARN_PREFIX="$WARN_PREFIX"
export MIR_SMOKE_FAIL_PREFIX="$FAIL_PREFIX"

pass() {
  printf '%s %s\n' "$PASS_PREFIX" "$1"
}

warn() {
  printf '%s %s\n' "$WARN_PREFIX" "$1"
}

fail() {
  printf '%s %s\n' "$FAIL_PREFIX" "$1" >&2
  exit 1
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
      fail "Usage: $0 [--no-nv] [--verbose]"
      ;;
  esac
  shift
done

if [[ ! -f "$ROOT/.env" ]]; then
  fail "Missing $ROOT/.env. Run ./scripts/workspace/init.sh first."
fi
pass ".env exists"

if ! command -v apptainer >/dev/null 2>&1; then
  fail "apptainer is not available on PATH."
fi
pass "apptainer on PATH"

# shellcheck disable=SC1091
source "$ROOT/scripts/lib/env.sh"
load_workspace_env "$ROOT"

IMAGE="${APPTAINER_IMAGE:-$ROOT/${APPTAINER_DVC_IMAGE:-containers/apptainer/images/mir-common.sif}}"

if [[ ! -f "$IMAGE" ]]; then
  fail "Missing Apptainer image: $IMAGE. Build or copy the shared image first."
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
    warn "nvidia-smi missing on host"
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

pass_prefix = os.environ.get("MIR_SMOKE_PASS_PREFIX", "[PASS]")
warn_prefix = os.environ.get("MIR_SMOKE_WARN_PREFIX", "[WARN]")
fail_prefix = os.environ.get("MIR_SMOKE_FAIL_PREFIX", "[FAIL]")
modules = ["torch", "torchaudio", "librosa", "mir_eval", "mirdata", "madmom", "mir_core"]
for name in modules:
    try:
        module = importlib.import_module(name)
    except Exception as exc:
        print(f"{fail_prefix} import {name}: {exc}")
        raise
    version = getattr(module, "__version__", "unknown")
    print(f"{pass_prefix} import {name} ({version})")

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
        print(f"{warn_prefix} nvidia-smi missing in container")
PY
else
  export MIR_SMOKE_VERBOSE="$VERBOSE"
  "$ROOT/scripts/apptainer/exec.sh" --no-nv python - <<'PY'
import importlib
import os
import platform

pass_prefix = os.environ.get("MIR_SMOKE_PASS_PREFIX", "[PASS]")
fail_prefix = os.environ.get("MIR_SMOKE_FAIL_PREFIX", "[FAIL]")
modules = ["torch", "torchaudio", "librosa", "mir_eval", "mirdata", "madmom", "mir_core"]
for name in modules:
    try:
        module = importlib.import_module(name)
    except Exception as exc:
        print(f"{fail_prefix} import {name}: {exc}")
        raise
    version = getattr(module, "__version__", "unknown")
    print(f"{pass_prefix} import {name} ({version})")

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
