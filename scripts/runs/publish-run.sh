#!/usr/bin/env bash
# publish-run.sh <experiment_hash> <attempt_id>
# Publishes a completed live attempt without deleting its HDD source.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENVFILE="$ROOT/.env"

if [[ ! -f "$ENVFILE" ]]; then
  echo "Missing $ENVFILE"
  exit 1
fi

# shellcheck disable=SC1090
source "$ROOT/scripts/lib/env.sh"
load_workspace_env "$ROOT"

: "${MIR_RUNS_ROOT:?MIR_RUNS_ROOT missing from .env}"
: "${MIR_OUTPUTS_ROOT:?MIR_OUTPUTS_ROOT missing from .env}"

EXPERIMENT_HASH="${1:?Usage: publish-run.sh <experiment_hash> <attempt_id>}"
ATTEMPT_ID="${2:?Usage: publish-run.sh <experiment_hash> <attempt_id>}"
PUBLICATION_DEFER_MARKER="${MIR_PUBLICATION_DEFER_MARKER:-$MIR_RUNS_ROOT/.publication-deferred}"
if [[ -e "$PUBLICATION_DEFER_MARKER" ]]; then
  echo "Publication deferred by operational marker: $PUBLICATION_DEFER_MARKER"
  exit 0
fi
PUBLISH_CLI="$MIR_OUTPUTS_ROOT/scripts/publish_completed_run.py"
MAX_GIT_PUSH_ATTEMPTS=8
publication_prepared=false
publication_was_published=false
publish_phase="reporting"

if [[ ! -f "$PUBLISH_CLI" ]]; then
  echo "Missing completed-run publisher: $PUBLISH_CLI"
  exit 1
fi

ensure_dvc_available() {
  if command -v dvc >/dev/null 2>&1; then
    return
  fi

  local conda_sh=""
  for candidate in "$HOME/miniforge3/etc/profile.d/conda.sh" "$HOME/miniconda3/etc/profile.d/conda.sh"; do
    if [[ -f "$candidate" ]]; then
      conda_sh="$candidate"
      break
    fi
  done

  if [[ -n "$conda_sh" ]]; then
    set +u
    # shellcheck disable=SC1090
    source "$conda_sh"
    conda activate MIR
    set -u
  fi

  if ! command -v dvc >/dev/null 2>&1; then
    echo "dvc is not available on PATH; install dvc[s3] in the MIR conda environment."
    exit 1
  fi
}

publisher() {
  PYTHONPATH="$MIR_OUTPUTS_ROOT${PYTHONPATH:+:$PYTHONPATH}" \
    python "$PUBLISH_CLI" "$@"
}

mark_failed() {
  local exit_code=$?
  trap - ERR
  if [[ "$publication_prepared" == "true" && "$publication_was_published" != "true" ]]; then
    publisher archive-state \
      "$EXPERIMENT_HASH" "$ATTEMPT_ID" publishing_failed \
      --outputs-root "$MIR_OUTPUTS_ROOT" \
      --error "Automatic publication failed during $publish_phase" >/dev/null 2>&1 || true
    publisher live-state \
      "$EXPERIMENT_HASH" "$ATTEMPT_ID" publishing_failed \
      --runs-root "$MIR_RUNS_ROOT" \
      --error "Automatic publication failed during $publish_phase" >/dev/null 2>&1 || true
  fi
  exit "$exit_code"
}
trap mark_failed ERR

ensure_dvc_available

# Serialize the local DVC/Git checkout. Per-attempt catalog entries avoid
# cross-host content conflicts when independent publishers later rebase.
exec 9>"$MIR_OUTPUTS_ROOT/.publish-worktree.lock"
if ! flock -w 600 9; then
  echo "Timed out waiting for the mir-outputs publication lock."
  exit 1
fi

PUBLISH_RESULT="$(
  publisher prepare \
    "$EXPERIMENT_HASH" "$ATTEMPT_ID" \
    --runs-root "$MIR_RUNS_ROOT" \
    --outputs-root "$MIR_OUTPUTS_ROOT"
)"
publication_prepared=true
publish_phase="dvc-push"

mapfile -t PUBLISH_PATHS < <(
  PUBLISH_RESULT="$PUBLISH_RESULT" python - <<'PY'
import json
import os

payload = json.loads(os.environ["PUBLISH_RESULT"])
for key in ("dvc_file", "archive_path", "catalog_entry", "publication_status"):
    print(payload[key])
PY
)
DVC_FILE="${PUBLISH_PATHS[0]}"
ARCHIVE_PATH="${PUBLISH_PATHS[1]}"
CATALOG_ENTRY="${PUBLISH_PATHS[2]}"
if [[ "${PUBLISH_PATHS[3]}" == "published" ]]; then
  publication_was_published=true
fi

if [[ -z "$DVC_FILE" ]]; then
  echo "Publisher did not return a DVC descriptor."
  exit 1
fi

(
  cd "$MIR_OUTPUTS_ROOT"
  dvc push "$DVC_FILE"
)

publish_phase="git-push"
publisher archive-state \
  "$EXPERIMENT_HASH" "$ATTEMPT_ID" published \
  --outputs-root "$MIR_OUTPUTS_ROOT" >/dev/null

(
  cd "$MIR_OUTPUTS_ROOT"
  git add -- "$ARCHIVE_PATH" "$CATALOG_ENTRY"
  if ! git diff --cached --quiet -- "$ARCHIVE_PATH" "$CATALOG_ENTRY"; then
    git commit --only -m "run: $EXPERIMENT_HASH/$ATTEMPT_ID" -- \
      "$ARCHIVE_PATH" "$CATALOG_ENTRY"
  fi

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
    echo "Failed to publish run after $MAX_GIT_PUSH_ATTEMPTS Git push attempts."
    exit 1
  fi
)

# The durable record is now present in both remotes. Only now does the retained
# live attempt move from publishing to published.
trap - ERR
publisher live-state \
  "$EXPERIMENT_HASH" "$ATTEMPT_ID" published \
  --runs-root "$MIR_RUNS_ROOT" >/dev/null

echo "Published run: $EXPERIMENT_HASH/$ATTEMPT_ID"
echo "Archive path: $MIR_OUTPUTS_ROOT/$ARCHIVE_PATH"
echo "Live source retained: $MIR_RUNS_ROOT"
