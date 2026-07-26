#!/usr/bin/env bash
set -euo pipefail

is_sourced() {
  [[ "${BASH_SOURCE[0]}" != "$0" ]]
}

fail() {
  echo "$*" >&2
  if is_sourced; then
    return 1
  fi
  exit 1
}

if ! is_sourced; then
  echo "This script is intended to be sourced so activation persists:"
  echo "  source ./scripts/delftblue/env.sh"
  echo
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

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

if ! load_delftblue_conda; then
  echo "Could not locate Conda or Miniforge under \$HOME on DelftBlue." >&2
  echo "Install Miniforge or Miniconda in your DelftBlue home, then rerun:" >&2
  echo "  ./scripts/workspace/init.sh" >&2
  echo "and choose: delftblue" >&2
  if is_sourced; then
    return 1
  fi
  exit 1
fi

command -v conda >/dev/null 2>&1 || fail "conda is not available after loading the DelftBlue Conda init script."
eval "$(conda shell.bash hook)"

export MIR_ENV_PROFILE=delftblue

if ! conda env list | awk 'NF > 0 && $1 !~ /^#/ { print $1 }' | grep -Fx MIR-hpc >/dev/null 2>&1; then
  echo "Conda environment MIR-hpc does not exist." >&2
  echo "Create it with:" >&2
  echo "  ./scripts/workspace/init.sh" >&2
  echo "and choose: delftblue" >&2
  if is_sourced; then
    return 1
  fi
  exit 1
fi

conda activate MIR-hpc

# shellcheck disable=SC1091
source "$ROOT/scripts/lib/env.sh"
load_workspace_env "$ROOT"

mkdir -p "${APPTAINER_CACHEDIR:-/scratch/$USER/.apptainer/cache}" "${TMPDIR:-/scratch/$USER/tmp}"
