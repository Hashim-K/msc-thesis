#!/usr/bin/env bash
# bootstrap.sh — first-time setup for the msc-thesis workspace (laptop)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
 
echo "==> Initialising submodules..."
git -C "$ROOT" submodule update --init --recursive
 
echo "==> Setting up .env..."
ENVFILE="$ROOT/.env"
if [ ! -f "$ENVFILE" ]; then
  cat > "$ENVFILE" <<ENVEOF
MIR_DATA_ROOT=$ROOT/repos/mir-data
MIR_OUTPUTS_ROOT=$ROOT/repos/mir-outputs
MIR_CORE_PATH=$ROOT/repos/mir-core
 
# MinIO / DVC — fill these in
MINIO_ENDPOINT=https://minio-api.hashimkarim.com
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
ENVEOF
  echo "    .env created — fill in AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
else
  echo "    .env already exists, skipping"
fi
 
source "$ENVFILE"
 
echo "==> Installing mir-core (editable)..."
pip install -e "$ROOT/repos/mir-core"
 
echo "==> Writing DVC credentials (local only, not committed)..."
for repo in mir-data mir-outputs; do
  DIR="$ROOT/repos/$repo"
  if [ -f "$DIR/.dvc/config" ]; then
    dvc remote modify origin access_key_id     "$AWS_ACCESS_KEY_ID"     --local -C "$DIR" 2>/dev/null || true
    dvc remote modify origin secret_access_key "$AWS_SECRET_ACCESS_KEY" --local -C "$DIR" 2>/dev/null || true
    echo "    DVC credentials written for $repo"
  fi
done
 
echo ""
echo "Bootstrap complete."
echo "Run: source .env"
echo "Then pull data: cd repos/mir-data && dvc pull"
