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

load_daic_miniconda() {
  local init_file

  if command -v conda >/dev/null 2>&1; then
    return 0
  fi

  if ! command -v module >/dev/null 2>&1 && ! command -v modulecmd >/dev/null 2>&1; then
    for init_file in \
      /usr/share/Modules/init/bash \
      /etc/profile.d/modules.sh \
      /usr/share/lmod/lmod/init/bash \
      /etc/profile \
      /etc/bashrc
    do
      if [[ -f "$init_file" ]]; then
        # shellcheck disable=SC1090
        source "$init_file" || true
      fi
      command -v module >/dev/null 2>&1 || command -v modulecmd >/dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        break
      fi
    done
  fi

  if command -v module >/dev/null 2>&1; then
    module use /opt/insy/modulefiles
    module load miniconda
  elif command -v modulecmd >/dev/null 2>&1; then
    eval "$(modulecmd bash use /opt/insy/modulefiles)"
    eval "$(modulecmd bash load miniconda)"
  fi

  command -v conda >/dev/null 2>&1
}

if ! load_daic_miniconda; then
  echo "Environment modules are not available; cannot load DAIC Miniconda." >&2
  echo "Tried module init files:" >&2
  echo "  /usr/share/Modules/init/bash" >&2
  echo "  /etc/profile.d/modules.sh" >&2
  echo "  /usr/share/lmod/lmod/init/bash" >&2
  echo "  /etc/profile" >&2
  echo "  /etc/bashrc" >&2
  echo "PATH=$PATH" >&2
  if is_sourced; then
    return 1
  fi
  exit 1
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
