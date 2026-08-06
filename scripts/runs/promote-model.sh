#!/usr/bin/env bash
# promote-model.sh <experiment_hash>/<attempt_id> <model-id>
# promote-model.sh <experiment_hash> <attempt_id> <model-id>
# Promotes a checkpoint from mir-outputs to mir-data/weights.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/env.sh"
load_workspace_env "$ROOT"

if [[ $# -eq 2 ]]; then
  RUN_REF="${1:?Usage: promote-model.sh <experiment_hash>/<attempt_id> <model-id>}"
  MODEL_ID="${2:?Usage: promote-model.sh <experiment_hash>/<attempt_id> <model-id>}"
  IFS=/ read -r EXPERIMENT_HASH ATTEMPT_ID extra <<< "$RUN_REF"
  if [[ -n "${extra:-}" || -z "${EXPERIMENT_HASH:-}" || -z "${ATTEMPT_ID:-}" ]]; then
    echo "ERROR: Run reference must be <experiment_hash>/<attempt_id>."
    exit 1
  fi
elif [[ $# -eq 3 ]]; then
  EXPERIMENT_HASH="${1:?Usage: promote-model.sh <experiment_hash> <attempt_id> <model-id>}"
  ATTEMPT_ID="${2:?Usage: promote-model.sh <experiment_hash> <attempt_id> <model-id>}"
  RUN_REF="$EXPERIMENT_HASH/$ATTEMPT_ID"
  MODEL_ID="${3:?Usage: promote-model.sh <experiment_hash> <attempt_id> <model-id>}"
else
  echo "Usage: promote-model.sh <experiment_hash>/<attempt_id> <model-id>"
  echo "   or: promote-model.sh <experiment_hash> <attempt_id> <model-id>"
  exit 1
fi

DST="${MIR_DATA_ROOT}/weights/${MODEL_ID}"

for component in "$EXPERIMENT_HASH" "$ATTEMPT_ID" "$MODEL_ID"; do
  if [[ ! "$component" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "ERROR: Identifiers may contain only letters, numbers, '.', '_' and '-'."
    exit 1
  fi
done

UNIFIED_ARCHIVE="${MIR_OUTPUTS_ROOT}/runs/${EXPERIMENT_HASH}/attempts/${ATTEMPT_ID}"
LEGACY_ARCHIVE="${MIR_OUTPUTS_ROOT}/runs/${RUN_REF}"

if [[ -f "$UNIFIED_ARCHIVE/published_run.json" || -f "$UNIFIED_ARCHIVE/data.dvc" ]]; then
  SNAPSHOT_ROOT="$UNIFIED_ARCHIVE/data/attempt"
  if [[ ! -d "$SNAPSHOT_ROOT" ]]; then
    echo "ERROR: The unified DVC snapshot is not materialized: $SNAPSHOT_ROOT"
    echo "Run: cd $MIR_OUTPUTS_ROOT && dvc pull runs/$EXPERIMENT_HASH/attempts/$ATTEMPT_ID/data.dvc"
    exit 1
  fi

  mapfile -d '' CHECKPOINT_FILES < <(
    find "$SNAPSHOT_ROOT/train" -type f \
      -path '*/fold_*/checkpoints/official/*' -print0 2>/dev/null | sort -z
  )
  if [[ ${#CHECKPOINT_FILES[@]} -eq 0 ]]; then
    echo "ERROR: No official training checkpoints found below $SNAPSHOT_ROOT/train"
    exit 1
  fi

  mkdir -p "$DST"
  for checkpoint in "${CHECKPOINT_FILES[@]}"; do
    fold_dir="${checkpoint#"$SNAPSHOT_ROOT/train/"}"
    fold_id="${fold_dir%%/*}"
    checkpoint_name="${checkpoint##*/}"
    cp "$checkpoint" "$DST/${fold_id}_${checkpoint_name}"
  done
  ARCHIVE_LAYOUT="unified-v2"
  CHECKPOINT_COUNT=${#CHECKPOINT_FILES[@]}
  SOURCE_ARCHIVE="runs/$EXPERIMENT_HASH/attempts/$ATTEMPT_ID"
elif [[ -d "$LEGACY_ARCHIVE/checkpoints" ]]; then
  mkdir -p "$DST"
  cp -r "$LEGACY_ARCHIVE/checkpoints/." "$DST/"
  ARCHIVE_LAYOUT="legacy-v1"
  CHECKPOINT_COUNT=$(find "$LEGACY_ARCHIVE/checkpoints" -type f | wc -l)
  SOURCE_ARCHIVE="runs/$RUN_REF"
else
  echo "ERROR: No unified or legacy checkpoint archive found for $RUN_REF"
  exit 1
fi

cat > "$DST/manifest.json" <<MANIFEST
{
  "model_id": "$MODEL_ID",
  "source_run_id": "$RUN_REF",
  "source_archive": "$SOURCE_ARCHIVE",
  "source_archive_layout": "$ARCHIVE_LAYOUT",
  "checkpoint_count": $CHECKPOINT_COUNT,
  "promoted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "",
  "architecture": "",
  "version": ""
}
MANIFEST
 
echo "Promoted: $RUN_REF -> $DST"
echo "Archive layout: $ARCHIVE_LAYOUT ($CHECKPOINT_COUNT checkpoints)"
echo ""
echo "Next steps:"
echo "  cd $MIR_DATA_ROOT"
echo "  dvc add weights/$MODEL_ID"
echo "  git add . && git commit -m 'promote: $MODEL_ID'"
echo "  dvc push"
