#!/usr/bin/env bash
# update-workspace.sh — refresh local workspace configuration
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if command -v dvc >/dev/null 2>&1; then
  echo "==> DVC already installed, skipping"
else
  echo "==> Installing DVC..."
  pip install "dvc[s3]"
fi

echo "==> Installing mir-core (editable)..."
pip install -e "$ROOT/repos/mir-core"

echo "==> Refreshing DVC remotes..."
"$ROOT/scripts/setup-dvc.sh"

echo ""
echo "Workspace update complete."
