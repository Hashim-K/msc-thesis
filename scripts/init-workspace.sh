#!/usr/bin/env bash
# init-workspace.sh — first-time setup for the msc-thesis workspace
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVFILE="$ROOT/.env"
ENVEXAMPLE="$ROOT/.env.example"
ENVROOT="$ROOT/repos/mir-environment"
created_env=false
target_kind=""
target_env_name=""
target_env_file=""

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

require_conda() {
  if command -v conda >/dev/null 2>&1; then
    return
  fi

  if [[ "$target_kind" == "daic" ]]; then
    echo "==> Loading Miniconda module for DAIC..."
    if load_daic_miniconda; then
      return
    fi
  fi

  echo "conda is not available on PATH."
  echo "Desktop: install Miniconda or Anaconda, then rerun this script."
  echo "DAIC:"
  echo "  module use /opt/insy/modulefiles"
  echo "  module load miniconda"
  exit 1
}

get_env_value() {
  local key="$1"
  local file="$2"
  awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, "", $0); print $0; exit}' "$file"
}

set_env_value() {
  local key="$1"
  local value="$2"
  local file="$3"
  if grep -q "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

prompt_target_environment() {
  local input_value

  read -r -p "Target environment [desktop/daic] (default: desktop): " input_value
  input_value="${input_value,,}"

  case "$input_value" in
    ""|desktop)
      target_kind="desktop"
      target_env_name="MIR"
      target_env_file="environment.yml"
      ;;
    daic)
      target_kind="daic"
      target_env_name="MIR-daic"
      target_env_file="environment-daic.yml"
      ;;
    *)
      echo "Unknown target: $input_value"
      echo "Use 'desktop' or 'daic'."
      exit 1
      ;;
  esac
}

conda_env_exists() {
  local env_name="$1"
  conda env list | awk 'NF > 0 && $1 !~ /^#/ { print $1 }' | grep -Fx "$env_name" >/dev/null 2>&1
}

create_or_update_target_environment() {
  echo "==> Setting up conda environment for $target_kind..."
  (
    cd "$ENVROOT"
    if conda_env_exists "$target_env_name"; then
      echo "    Updating existing environment: $target_env_name"
      conda env update -n "$target_env_name" -f "$target_env_file" --prune
    else
      echo "    Creating environment: $target_env_name"
      conda env create -f "$target_env_file"
    fi
  )
}

activate_target_environment() {
  eval "$(conda shell.bash hook)"
  conda activate "$target_env_name"
}

prompt_path_value() {
  local key="$1"
  local label="$2"
  local default_value="$3"
  local current_value
  local prompt_value
  local input_value

  current_value="$(get_env_value "$key" "$ENVFILE")"
  if [[ -n "$current_value" && "$current_value" != /path/to/msc-thesis/* ]]; then
    prompt_value="$current_value"
  else
    prompt_value="$default_value"
  fi

  read -r -p "$label [$prompt_value]: " input_value
  if [[ -n "$input_value" ]]; then
    set_env_value "$key" "$input_value" "$ENVFILE"
  else
    set_env_value "$key" "$prompt_value" "$ENVFILE"
  fi
}

echo "==> Initialising submodules..."
(
  cd "$ROOT"
  git submodule update --init --recursive
)

echo "==> Setting up .env..."
if [[ ! -f "$ENVFILE" ]]; then
  if [[ ! -f "$ENVEXAMPLE" ]]; then
    echo "Missing $ENVEXAMPLE"
    exit 1
  fi
  cp "$ENVEXAMPLE" "$ENVFILE"
  created_env=true
  echo "    .env created from .env.example"
  echo "    Fill in AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY before using DVC"
else
  echo "    .env already exists, skipping"
fi

data_default="$ROOT/repos/mir-data"
outputs_default="$ROOT/repos/mir-outputs"
core_default="$ROOT/repos/mir-core"

if $created_env || [[ "$(get_env_value MIR_DATA_ROOT "$ENVFILE")" == /path/to/msc-thesis/* ]] || [[ "$(get_env_value MIR_OUTPUTS_ROOT "$ENVFILE")" == /path/to/msc-thesis/* ]] || [[ "$(get_env_value MIR_CORE_PATH "$ENVFILE")" == /path/to/msc-thesis/* ]]; then
  echo "==> Workspace paths..."
  prompt_path_value "MIR_DATA_ROOT" "Path to mir-data" "$data_default"
  prompt_path_value "MIR_OUTPUTS_ROOT" "Path to mir-outputs" "$outputs_default"
  prompt_path_value "MIR_CORE_PATH" "Path to mir-core" "$core_default"
fi

export MIR_DATA_ROOT="$(get_env_value MIR_DATA_ROOT "$ENVFILE")"
export MIR_OUTPUTS_ROOT="$(get_env_value MIR_OUTPUTS_ROOT "$ENVFILE")"
export MIR_CORE_PATH="$(get_env_value MIR_CORE_PATH "$ENVFILE")"

prompt_target_environment
require_conda

set -a
source "$ENVFILE"
set +a

create_or_update_target_environment
activate_target_environment

echo "==> Installing mir-core (editable) into $target_env_name..."
python -m pip install -e "$ROOT/repos/mir-core"

echo "==> Configuring DVC remotes in $target_env_name..."
"$ROOT/scripts/setup-dvc.sh"

echo ""
echo "Workspace initialization complete."
echo "Target environment: $target_env_name"
echo "Environment file: $ENVFILE"
echo "Activate later with: conda activate $target_env_name"
echo "Data pull: cd $ROOT/repos/mir-data && dvc pull"
