#!/usr/bin/env bash
# update-workspace.sh — refresh local workspace configuration
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

require_python
install_dvc_if_needed

echo "==> Installing mir-core (editable)..."
python -m pip install -e "$ROOT/repos/mir-core"

echo "==> Refreshing DVC remotes..."
"$ROOT/scripts/setup-dvc.sh"

echo ""
echo "Workspace update complete."
