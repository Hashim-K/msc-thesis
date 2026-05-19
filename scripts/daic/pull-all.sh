#!/usr/bin/env bash
set -uo pipefail

ROOT="/home/nfs/hashimkarim/msc-thesis"
failures=()

pull_repo() {
  local path="$1"
  local name="$2"
  echo "==> $name"

  if ! git -C "$path" rev-parse --git-dir >/dev/null 2>&1; then
    echo "    skip: not a git repo"
    return 1
  fi

  local branch
  branch=$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null)

  if [[ "$branch" == "HEAD" ]]; then
    echo "    detached HEAD — checking out main"
    git -C "$path" checkout main || { echo "    failed to checkout main"; return 1; }
  fi

  if git -C "$path" pull --ff-only origin main 2>&1; then
    echo "    ok"
  else
    echo "    failed"
    return 1
  fi
}

for repo in \
  "$ROOT:msc-thesis" \
  "$ROOT/repos/mir-core:mir-core" \
  "$ROOT/repos/mir-train-hpc:mir-train-hpc"
do
  path="${repo%%:*}"
  name="${repo##*:}"
  pull_repo "$path" "$name" || failures+=("$name")
  echo
done

if (( ${#failures[@]} > 0 )); then
  echo "Failures/skips:"
  printf '  - %s\n' "${failures[@]}"
  exit 1
fi

echo "All repos up to date."
