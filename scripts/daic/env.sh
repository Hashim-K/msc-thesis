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
  echo "  source ./scripts/daic/env.sh"
  echo
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
else
  fail "Environment modules are not available; cannot load DAIC Miniconda."
fi

command -v conda >/dev/null 2>&1 || fail "conda is not available after loading the DAIC Miniconda module."
eval "$(conda shell.bash hook)"

export MIR_ENV_PROFILE=daic

if ! conda env list | awk 'NF > 0 && $1 !~ /^#/ { print $1 }' | grep -Fx MIR-hpc >/dev/null 2>&1; then
  echo "Conda environment MIR-hpc does not exist." >&2
  echo "Create it with:" >&2
  echo "  ./scripts/workspace/init.sh" >&2
  echo "and choose: daic" >&2
  if is_sourced; then
    return 1
  fi
  exit 1
fi

conda activate MIR-hpc
