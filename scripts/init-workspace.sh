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
target_env_prefix=""

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
    "$HOME/miniconda3/etc/profile.d/conda.sh" \
    "$HOME/miniforge3/etc/profile.d/conda.sh" \
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

require_conda() {
  if command -v conda >/dev/null 2>&1; then
    return
  fi

  if [[ "$target_kind" == "daic" ]]; then
    echo "==> Loading Miniconda module for DAIC..."
    if load_daic_miniconda; then
      return
    fi
  elif [[ "$target_kind" == "delftblue" ]]; then
    echo "==> Looking for a user-installed Conda on DelftBlue..."
    if load_delftblue_conda; then
      return
    fi
  fi

  echo "conda is not available on PATH."
  echo "Desktop: install Miniconda or Anaconda, then rerun this script."
  echo "DAIC:"
  echo "  module use /opt/insy/modulefiles"
  echo "  module load miniconda"
  echo "DelftBlue:"
  echo "  install Miniconda or Miniforge in \$HOME, then rerun this script"
  exit 1
}

get_env_value() {
  local key="$1"
  local file="$2"
  awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, "", $0); print $0; exit}' "$file"
}

is_placeholder_value() {
  local value="$1"
  [[ -z "$value" || "$value" == /path/to/* ]]
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

  read -r -p "Target environment [desktop/daic/delftblue] (default: desktop): " input_value
  input_value="${input_value,,}"

  case "$input_value" in
    ""|desktop)
      target_kind="desktop"
      target_env_name="MIR"
      target_env_file="environment.yml"
      ;;
    daic)
      target_kind="daic"
      target_env_name="MIR-hpc"
      target_env_file="environment-hpc-bootstrap.yml"
      ;;
    delftblue)
      target_kind="delftblue"
      target_env_name="MIR-hpc"
      target_env_file="environment-hpc-bootstrap.yml"
      ;;
    *)
      echo "Unknown target: $input_value"
      echo "Use 'desktop', 'daic', or 'delftblue'."
      exit 1
      ;;
  esac
}

conda_env_exists() {
  local env_name="$1"
  local env_prefix="$HOME/.conda/envs/$env_name"
  [[ -d "$env_prefix" ]] && return 0
  conda env list | awk 'NF > 0 && $1 !~ /^#/ { print $1 }' | grep -Fx "$env_name" >/dev/null 2>&1
}

debug_env_setup() {
  if [[ "${MIR_DEBUG_ENV_SETUP:-0}" != "1" ]]; then
    return
  fi

  echo "==> Environment setup debug"
  echo "target_kind=$target_kind"
  echo "target_env_name=$target_env_name"
  echo "target_env_file=$target_env_file"
  echo "target_env_prefix=$target_env_prefix"
  echo "pwd=$(pwd)"
  echo "hostname=$(hostname)"
  echo "PATH=$PATH"
  echo "conda=$(command -v conda || echo missing)"
  if command -v conda >/dev/null 2>&1; then
    echo "conda_version=$(conda --version 2>&1)"
  fi
  if command -v free >/dev/null 2>&1; then
    free -h || true
  fi
  if command -v ulimit >/dev/null 2>&1; then
    ulimit -a || true
  fi
  echo "env_file_exists=$( [[ -f "$ENVROOT/$target_env_file" ]] && echo yes || echo no )"
}

run_conda_env_command() {
  local mode="$1"
  local env_file="$2"
  echo "    Solver path: conda"
  if [[ "$mode" == "create" ]]; then
    conda env create -f "$env_file"
  else
    conda env update -n "$target_env_name" -f "$env_file" --prune
  fi
}

create_or_update_target_environment() {
  echo "==> Setting up conda environment for $target_kind..."
  (
    cd "$ENVROOT"
    debug_env_setup
    if conda_env_exists "$target_env_name"; then
      echo "    Updating existing environment: $target_env_name"
      run_conda_env_command "update" "$target_env_file"
    else
      echo "    Creating environment: $target_env_name"
      run_conda_env_command "create" "$target_env_file"
    fi
  )
}

activate_target_environment() {
  eval "$(conda shell.bash hook)"
  if [[ -d "$target_env_prefix" ]]; then
    conda activate "$target_env_prefix"
  else
    conda activate "$target_env_name"
  fi
}

prompt_path_value() {
  local key="$1"
  local label="$2"
  local default_value="$3"
  local current_value
  local prompt_value
  local input_value

  current_value="$(get_env_value "$key" "$ENVFILE")"
  if ! is_placeholder_value "$current_value"; then
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

prompt_target_environment
target_env_prefix="$HOME/.conda/envs/$target_env_name"

data_default="$ROOT/repos/mir-data"
outputs_default="$ROOT/repos/mir-outputs"
core_default="$ROOT/repos/mir-core"
if [[ "$target_kind" == "daic" || "$target_kind" == "delftblue" ]]; then
  shared_default="/tudelft.net/staff-umbrella/mirworkspace"
else
  shared_default="$ROOT/shared"
fi
runs_default="$shared_default/runs"
apptainer_default="$shared_default/containers/mir-common.sif"

if $created_env || is_placeholder_value "$(get_env_value MIR_DATA_ROOT "$ENVFILE")" || is_placeholder_value "$(get_env_value MIR_OUTPUTS_ROOT "$ENVFILE")" || is_placeholder_value "$(get_env_value MIR_CORE_PATH "$ENVFILE")" || is_placeholder_value "$(get_env_value MIR_SHARED_ROOT "$ENVFILE")" || is_placeholder_value "$(get_env_value MIR_RUNS_ROOT "$ENVFILE")" || is_placeholder_value "$(get_env_value APPTAINER_IMAGE "$ENVFILE")"; then
  echo "==> Workspace paths..."
  prompt_path_value "MIR_DATA_ROOT" "Path to mir-data" "$data_default"
  prompt_path_value "MIR_OUTPUTS_ROOT" "Path to mir-outputs" "$outputs_default"
  prompt_path_value "MIR_CORE_PATH" "Path to mir-core" "$core_default"
  prompt_path_value "MIR_SHARED_ROOT" "Path to shared project storage" "$shared_default"
  prompt_path_value "MIR_RUNS_ROOT" "Path to live run staging" "$runs_default"
  prompt_path_value "APPTAINER_IMAGE" "Path to shared Apptainer image" "$apptainer_default"
fi

export MIR_DATA_ROOT="$(get_env_value MIR_DATA_ROOT "$ENVFILE")"
export MIR_OUTPUTS_ROOT="$(get_env_value MIR_OUTPUTS_ROOT "$ENVFILE")"
export MIR_CORE_PATH="$(get_env_value MIR_CORE_PATH "$ENVFILE")"
export MIR_SHARED_ROOT="$(get_env_value MIR_SHARED_ROOT "$ENVFILE")"
export MIR_RUNS_ROOT="$(get_env_value MIR_RUNS_ROOT "$ENVFILE")"
export APPTAINER_IMAGE="$(get_env_value APPTAINER_IMAGE "$ENVFILE")"
require_conda

set -a
source "$ENVFILE"
set +a

mkdir -p "$MIR_SHARED_ROOT/dvc-cache" "$MIR_RUNS_ROOT" "$(dirname "$APPTAINER_IMAGE")"

create_or_update_target_environment
activate_target_environment

echo "==> Installing mir-core (editable) into $target_env_name..."
if [[ "$target_kind" == "desktop" ]]; then
  python -m pip install -e "$ROOT/repos/mir-core"
else
  echo "==> Skipping editable mir-core install for $target_kind"
  echo "    Full runtime is provided by the shared Apptainer image."
fi

echo "==> Configuring DVC remotes in $target_env_name..."
"$ROOT/scripts/setup-dvc.sh"

echo ""
echo "Workspace initialization complete."
echo "Target environment: $target_env_name"
echo "Environment file: $ENVFILE"
echo "Activate later with: conda activate $target_env_name"
echo "Data pull: cd $ROOT/repos/mir-data && dvc pull"
echo "Outputs browse: cd $ROOT/repos/mir-outputs && dvc pull"
