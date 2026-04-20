#!/usr/bin/env bash
# init.sh — first-time setup for the msc-thesis workspace
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENVFILE="$ROOT/.env"
ENVROOT="$ROOT/repos/mir-environment"
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

  read -r -p "Target platform [legion/daic/delftblue] (default: legion): " input_value
  input_value="${input_value,,}"

  case "$input_value" in
    ""|desktop|legion)
      target_kind="legion"
      target_env_name="MIR"
      target_env_file="environment.yml"
      ;;
    daic)
      target_kind="daic"
      target_env_name="MIR-hpc"
      target_env_file="environment-hpc.yml"
      ;;
    delftblue)
      target_kind="delftblue"
      target_env_name="MIR-hpc"
      target_env_file="environment-hpc.yml"
      ;;
    *)
      echo "Unknown target: $input_value"
      echo "Use 'legion', 'daic', or 'delftblue'."
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

prompt_env_value() {
  local key="$1"
  local label="$2"
  local current_value input_value

  current_value="$(get_env_value "$key" "$ENVFILE")"
  read -r -p "$label [$current_value]: " input_value
  if [[ -n "$input_value" ]]; then
    set_env_value "$key" "$input_value" "$ENVFILE"
  fi
}

echo "==> Initialising submodules..."
(
  cd "$ROOT"
  git submodule update --init --recursive
)

echo "==> Setting up .env..."
if [[ ! -f "$ENVFILE" ]]; then
  echo "Missing tracked env file: $ENVFILE"
  echo "Restore it with: git checkout -- .env"
  exit 1
else
  echo "    .env exists"
fi

prompt_target_environment
platform_env_file="$ROOT/.env.$target_kind"
if [[ ! -f "$platform_env_file" ]]; then
  echo "Missing platform env file: $platform_env_file"
  exit 1
fi

set_env_value "MIR_ENV_PROFILE" "$target_kind" "$ENVFILE"
echo "==> MinIO / DVC credentials..."
prompt_env_value "AWS_ACCESS_KEY_ID" "MinIO access key"
prompt_env_value "AWS_SECRET_ACCESS_KEY" "MinIO secret key"
target_env_prefix="$HOME/.conda/envs/$target_env_name"

require_conda

# shellcheck disable=SC1091
source "$ROOT/scripts/lib/env.sh"
load_workspace_env "$ROOT"

mkdir -p "$MIR_SHARED_ROOT/dvc-cache" "$MIR_RUNS_ROOT" "$(dirname "$APPTAINER_IMAGE")"

create_or_update_target_environment
activate_target_environment

echo "==> Installing mir-core (editable) into $target_env_name..."
if [[ "$target_kind" == "legion" ]]; then
  python -m pip install -e "$ROOT/repos/mir-core"
else
  echo "==> Skipping editable mir-core install for $target_kind"
  echo "    Full runtime is provided by the shared Apptainer image."
fi

echo "==> Configuring DVC remotes in $target_env_name..."
"$ROOT/scripts/workspace/dvc.sh"

echo ""
echo "Workspace initialization complete."
echo "Target environment: $target_env_name"
echo "Environment file: $ENVFILE"
echo "Activate later with: conda activate $target_env_name"
echo "Data pull: cd $ROOT/repos/mir-data && dvc pull"
echo "Outputs browse: cd $ROOT/repos/mir-outputs && dvc pull"
