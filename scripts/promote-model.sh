#!/usr/bin/env bash
# promote-model.sh <experiment_hash>/<attempt_id> <model-id>
# promote-model.sh <experiment_hash> <attempt_id> <model-id>
# Promotes a checkpoint from mir-outputs to mir-data/weights.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/env.sh"
load_env_file "$ROOT/.env"

if [[ $# -eq 2 ]]; then
  RUN_REF="${1:?Usage: promote-model.sh <experiment_hash>/<attempt_id> <model-id>}"
  MODEL_ID="${2:?Usage: promote-model.sh <experiment_hash>/<attempt_id> <model-id>}"
elif [[ $# -eq 3 ]]; then
  RUN_REF="${1:?Usage: promote-model.sh <experiment_hash> <attempt_id> <model-id>}/${2:?Usage: promote-model.sh <experiment_hash> <attempt_id> <model-id>}"
  MODEL_ID="${3:?Usage: promote-model.sh <experiment_hash> <attempt_id> <model-id>}"
else
  echo "Usage: promote-model.sh <experiment_hash>/<attempt_id> <model-id>"
  echo "   or: promote-model.sh <experiment_hash> <attempt_id> <model-id>"
  exit 1
fi

SRC="${MIR_OUTPUTS_ROOT}/runs/${RUN_REF}/checkpoints"
DST="${MIR_DATA_ROOT}/weights/${MODEL_ID}"
 
[ -d "$SRC" ] || { echo "ERROR: Not found: $SRC"; exit 1; }
 
mkdir -p "$DST"
cp -r "$SRC/." "$DST/"
 
cat > "$DST/manifest.json" <<MANIFEST
{
  "model_id": "$MODEL_ID",
  "source_run_id": "$RUN_REF",
  "promoted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "",
  "architecture": "",
  "version": ""
}
MANIFEST
 
echo "Promoted: $RUN_REF -> $DST"
echo ""
echo "Next steps:"
echo "  cd $MIR_DATA_ROOT"
echo "  dvc add weights/$MODEL_ID"
echo "  git add . && git commit -m 'promote: $MODEL_ID'"
echo "  dvc push"
