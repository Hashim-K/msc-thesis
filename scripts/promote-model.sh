#!/usr/bin/env bash
# promote-model.sh <run-id> <model-id>
# Promotes a checkpoint from mir-outputs to mir-data/weights.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT/.env" ] && source "$ROOT/.env"
 
RUN_ID="${1:?Usage: promote-model.sh <run-id> <model-id>}"
MODEL_ID="${2:?Usage: promote-model.sh <run-id> <model-id>}"
 
SRC="${MIR_OUTPUTS_ROOT}/runs/${RUN_ID}/checkpoints"
DST="${MIR_DATA_ROOT}/weights/${MODEL_ID}"
 
[ -d "$SRC" ] || { echo "ERROR: Not found: $SRC"; exit 1; }
 
mkdir -p "$DST"
cp -r "$SRC/." "$DST/"
 
cat > "$DST/manifest.json" <<MANIFEST
{
  "model_id": "$MODEL_ID",
  "source_run_id": "$RUN_ID",
  "promoted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "",
  "architecture": "",
  "version": ""
}
MANIFEST
 
echo "Promoted: $RUN_ID -> $DST"
echo ""
echo "Next steps:"
echo "  cd $MIR_DATA_ROOT"
echo "  dvc add weights/$MODEL_ID"
echo "  git add . && git commit -m 'promote: $MODEL_ID'"
echo "  dvc push"
