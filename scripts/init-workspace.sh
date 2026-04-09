#!/usr/bin/env bash
# init-workspace.sh — first-time setup for the msc-thesis workspace
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVFILE="$ROOT/.env"
ENVEXAMPLE="$ROOT/.env.example"
created_env=false

require_python() {
  if ! command -v python >/dev/null 2>&1; then
    echo "Python is not available on PATH."
    echo "Activate a Python 3.10+ environment first, for example:"
    echo "  conda activate MIR"
    echo "  conda activate MIR-daic"
    exit 1
  fi

  if ! python - <<'PY' >/dev/null 2>&1
import sys
raise SystemExit(0 if sys.version_info >= (3, 10) else 1)
PY
  then
    echo "Python 3.10+ is required."
    echo "Current interpreter: $(python --version 2>&1)"
    echo "Activate a compatible environment first, for example:"
    echo "  conda activate MIR"
    echo "  conda activate MIR-daic"
    exit 1
  fi
}

install_dvc_if_needed() {
  if command -v dvc >/dev/null 2>&1 && python -m pip show dvc >/dev/null 2>&1; then
    echo "==> DVC already installed in the active Python environment, skipping"
  else
    echo "==> Installing DVC into the active Python environment..."
    python -m pip install "dvc[s3]"
  fi
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

require_python
install_dvc_if_needed

echo "==> Installing mir-core (editable)..."
python -m pip install -e "$ROOT/repos/mir-core"

echo "==> Configuring DVC remotes..."
"$ROOT/scripts/setup-dvc.sh"

echo ""
echo "Workspace initialization complete."
echo "Environment file: $ENVFILE"
echo "Data pull: cd $ROOT/repos/mir-data && dvc pull"
