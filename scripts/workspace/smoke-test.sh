#!/usr/bin/env bash
# smoke-test.sh <desktop|daic|daic-experimental|delftblue> [--pull-test]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENVFILE="$ROOT/.env"
PULL_TEST="no"

usage() {
  echo "Usage: $0 <desktop|daic|daic-experimental|delftblue> [--pull-test]"
  exit 1
}

load_daic_miniconda() {
  if command -v conda >/dev/null 2>&1; then
    return 0
  fi

  if command -v module >/dev/null 2>&1; then
    module use /opt/insy/modulefiles
    module load miniconda
  elif command -v modulecmd >/dev/null 2>&1; then
    eval "$(modulecmd bash use /opt/insy/modulefiles)"
    eval "$(modulecmd bash load miniconda)"
  elif [[ -f /etc/profile.d/modules.sh ]]; then
    # shellcheck disable=SC1091
    source /etc/profile.d/modules.sh
    module use /opt/insy/modulefiles
    module load miniconda
  elif [[ -f /usr/share/Modules/init/bash ]]; then
    # shellcheck disable=SC1091
    source /usr/share/Modules/init/bash
    module use /opt/insy/modulefiles
    module load miniconda
  fi

  command -v conda >/dev/null 2>&1
}

load_delftblue_conda() {
  local candidate

  if command -v conda >/dev/null 2>&1; then
    return 0
  fi

  for candidate in \
    "$HOME/miniforge3/etc/profile.d/conda.sh" \
    "$HOME/miniconda3/etc/profile.d/conda.sh" \
    "$HOME/mambaforge/etc/profile.d/conda.sh"
  do
    if [[ -f "$candidate" ]]; then
      # shellcheck disable=SC1090
      source "$candidate"
      command -v conda >/dev/null 2>&1 && return 0
    fi
  done

  return 1
}

require_conda_for_target() {
  local target="$1"

  if command -v conda >/dev/null 2>&1; then
    return
  fi

  case "$target" in
    daic|daic-experimental)
      echo "==> Loading Miniconda module for DAIC..."
      load_daic_miniconda || {
        echo "Failed to load DAIC Miniconda module."
        exit 1
      }
      ;;
    delftblue)
      echo "==> Looking for Conda/Miniforge on DelftBlue..."
      load_delftblue_conda || {
        echo "Failed to locate a DelftBlue Conda installation under \$HOME."
        exit 1
      }
      ;;
    desktop)
      echo "conda is not available on PATH."
      exit 1
      ;;
  esac
}

activate_env() {
  local env_name="$1"
  eval "$(conda shell.bash hook)"
  conda activate "$env_name"
}

show_var() {
  local key="$1"
  printf '%s=%s\n' "$key" "${!key}"
}

TARGET="${1:-}"
[[ -n "$TARGET" ]] || usage
shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pull-test)
      PULL_TEST="yes"
      ;;
    *)
      usage
      ;;
  esac
  shift
done

case "$TARGET" in
  desktop)
    TARGET_ENV="MIR"
    ;;
  daic|daic-experimental)
    TARGET_ENV="MIR-hpc"
    ;;
  delftblue)
    TARGET_ENV="MIR-hpc"
    ;;
  *)
    usage
    ;;
esac

if [[ ! -f "$ENVFILE" ]]; then
  echo "Missing $ENVFILE"
  echo "Run ./scripts/workspace/init.sh first."
  exit 1
fi

require_conda_for_target "$TARGET"
activate_env "$TARGET_ENV"

# shellcheck disable=SC1090
source "$ROOT/scripts/lib/env.sh"
load_workspace_env "$ROOT"

echo "==> Environment"
echo "Target: $TARGET"
echo "Conda env: $TARGET_ENV"
python --version
echo "python: $(which python)"

echo
echo "==> Bootstrap environment checks"
dvc version
python - <<'PY'
import yaml
import click
import rich
print("python_imports=ok")
PY

echo
echo "==> Path model"
show_var MIR_DATA_ROOT
show_var MIR_OUTPUTS_ROOT
show_var MIR_CORE_PATH
show_var MIR_SHARED_ROOT
show_var MIR_RUNS_ROOT
show_var APPTAINER_IMAGE

echo
echo "==> Shared directories"
for path in "$MIR_SHARED_ROOT" "$MIR_SHARED_ROOT/dvc-cache" "$MIR_RUNS_ROOT" "$(dirname "$APPTAINER_IMAGE")"; do
  if [[ -e "$path" ]]; then
    ls -ld "$path"
  else
    echo "Missing path: $path"
    exit 1
  fi
done

echo
echo "==> mir-data DVC config"
(
  cd "$MIR_DATA_ROOT"
  echo "cache.dir=$(dvc config --local cache.dir)"
  echo "cache.type=$(dvc config --local cache.type)"
  dvc remote list
)

if [[ "$PULL_TEST" == "yes" ]]; then
  echo
  echo "==> DVC pull smoke test"
  (
    cd "$MIR_DATA_ROOT"
    dvc pull datasets/processed/brid.dvc
    if [[ -e datasets/processed/brid/manifest.json ]]; then
      ls -l datasets/processed/brid/manifest.json
    fi
  )
fi

echo
echo "Smoke test passed."
