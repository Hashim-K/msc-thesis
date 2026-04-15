#!/usr/bin/env bash
# publish-run.sh <experiment_hash> <attempt_id>
# Archives a completed live run into mir-outputs, DVC-pushes heavy artifacts,
# and Git-pushes the per-run metadata.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVFILE="$ROOT/.env"

if [[ ! -f "$ENVFILE" ]]; then
  echo "Missing $ENVFILE"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENVFILE"
set +a

: "${MIR_RUNS_ROOT:?MIR_RUNS_ROOT missing from .env}"
: "${MIR_OUTPUTS_ROOT:?MIR_OUTPUTS_ROOT missing from .env}"

EXPERIMENT_HASH="${1:?Usage: publish-run.sh <experiment_hash> <attempt_id>}"
ATTEMPT_ID="${2:?Usage: publish-run.sh <experiment_hash> <attempt_id>}"
LIVE_RUN_DIR="$MIR_RUNS_ROOT/$EXPERIMENT_HASH/$ATTEMPT_ID"
ARCHIVE_RUN_DIR="$MIR_OUTPUTS_ROOT/runs/$EXPERIMENT_HASH/$ATTEMPT_ID"
LOCK_DIR="$MIR_OUTPUTS_ROOT/.publish-lock"
MAX_LOCK_ATTEMPTS=300
MAX_GIT_PUSH_ATTEMPTS=8
lock_acquired=false
publish_succeeded=false
metadata_files=(run.json metrics.json config.yaml)
heavy_dirs=(checkpoints logs)

cleanup() {
  if [[ "$lock_acquired" == "true" && -d "$LOCK_DIR" ]]; then
    rmdir "$LOCK_DIR" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

require_path() {
  local path="$1"
  local label="$2"
  if [[ ! -e "$path" ]]; then
    echo "Missing $label: $path"
    exit 1
  fi
}

for file_name in "${metadata_files[@]}"; do
  require_path "$LIVE_RUN_DIR/$file_name" "$file_name"
done

for dir_name in "${heavy_dirs[@]}"; do
  if [[ ! -d "$LIVE_RUN_DIR/$dir_name" ]]; then
    echo "Missing $dir_name directory: $LIVE_RUN_DIR/$dir_name"
    exit 1
  fi
done

python - "$LIVE_RUN_DIR/run.json" "$EXPERIMENT_HASH" "$ATTEMPT_ID" <<'PY'
import json
import sys

run_json_path, experiment_hash, attempt_id = sys.argv[1:4]
required = [
    "experiment_hash",
    "attempt_id",
    "slurm_job_id",
    "cluster",
    "hostname",
    "scheduled_at",
    "started_at",
    "finished_at",
    "status",
    "mir_core_commit",
    "mir_train_hpc_commit",
    "dataset_versions",
    "artifacts",
    "summary",
]

with open(run_json_path, "r", encoding="utf-8") as handle:
    payload = json.load(handle)

missing = [key for key in required if key not in payload]
if missing:
    raise SystemExit(f"run.json missing keys: {', '.join(missing)}")

if payload["experiment_hash"] != experiment_hash:
    raise SystemExit(
        f"run.json experiment_hash mismatch: {payload['experiment_hash']} != {experiment_hash}"
    )

if payload["attempt_id"] != attempt_id:
    raise SystemExit(
        f"run.json attempt_id mismatch: {payload['attempt_id']} != {attempt_id}"
    )
PY

for lock_attempt in $(seq 1 "$MAX_LOCK_ATTEMPTS"); do
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    lock_acquired=true
    break
  fi
  sleep 2
done

if [[ "$lock_acquired" != "true" ]]; then
  echo "Could not acquire publish lock: $LOCK_DIR"
  exit 1
fi

if [[ -e "$ARCHIVE_RUN_DIR" ]]; then
  echo "Archive target already exists: $ARCHIVE_RUN_DIR"
  exit 1
fi

mkdir -p "$(dirname "$ARCHIVE_RUN_DIR")"
mkdir -p "$ARCHIVE_RUN_DIR"

for file_name in "${metadata_files[@]}"; do
  cp -a "$LIVE_RUN_DIR/$file_name" "$ARCHIVE_RUN_DIR/$file_name"
done

for dir_name in "${heavy_dirs[@]}"; do
  cp -a "$LIVE_RUN_DIR/$dir_name" "$ARCHIVE_RUN_DIR/$dir_name"
done

(
  cd "$MIR_OUTPUTS_ROOT"
  dvc add "runs/$EXPERIMENT_HASH/$ATTEMPT_ID/checkpoints"
  dvc add "runs/$EXPERIMENT_HASH/$ATTEMPT_ID/logs"
  dvc push "runs/$EXPERIMENT_HASH/$ATTEMPT_ID/checkpoints.dvc" "runs/$EXPERIMENT_HASH/$ATTEMPT_ID/logs.dvc"
  git add "runs/$EXPERIMENT_HASH/$ATTEMPT_ID"
  if git diff --cached --quiet; then
    echo "No changes staged for publish."
    exit 1
  fi
  git commit -m "run: $EXPERIMENT_HASH/$ATTEMPT_ID"

  pushed=false
  for git_attempt in $(seq 1 "$MAX_GIT_PUSH_ATTEMPTS"); do
    git pull --rebase origin main || {
      git rebase --abort >/dev/null 2>&1 || true
      sleep 2
      continue
    }

    if git push origin HEAD:main; then
      pushed=true
      break
    fi
    sleep 2
  done

  if [[ "$pushed" != "true" ]]; then
    echo "Failed to publish run after $MAX_GIT_PUSH_ATTEMPTS git push attempts."
    exit 1
  fi
)

publish_succeeded=true
rm -rf "$LIVE_RUN_DIR"
rmdir "$(dirname "$LIVE_RUN_DIR")" >/dev/null 2>&1 || true

echo "Published run: $EXPERIMENT_HASH/$ATTEMPT_ID"
echo "Archive path: $ARCHIVE_RUN_DIR"
