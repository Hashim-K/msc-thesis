#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
failures=()

pull_repo() {
  local path="$1"
  local name="$2"

  echo "==> $name"
  if ! (cd "$path" && git rev-parse --git-dir >/dev/null 2>&1); then
    echo "    skip: not a git repo"
    return 1
  fi

  local branch
  branch="$(cd "$path" && git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [[ "$branch" != "main" ]]; then
    if [[ "$branch" == "HEAD" ]]; then
      echo "    detached HEAD - checking out main"
    else
      echo "    branch $branch - checking out main"
    fi
    (cd "$path" && git checkout main) || {
      echo "    failed to checkout main"
      return 1
    }
  fi

  if (cd "$path" && git pull --ff-only origin main 2>&1 >/dev/null); then
    echo "    ok"
    echo "    latest commit: $(cd "$path" && git log -1 --format='%h - %s')"
  else
    echo "    failed"
    return 1
  fi
}

pull_repo "$ROOT" "msc-thesis" || failures+=("msc-thesis")
echo

for repo_dir in "$ROOT"/repos/*; do
  [[ -d "$repo_dir" ]] || continue
  name="$(basename "$repo_dir")"
  pull_repo "$repo_dir" "$name" || failures+=("$name")
  echo
done

if (( ${#failures[@]} > 0 )); then
  echo "Failures/skips:"
  printf '  - %s\n' "${failures[@]}"
  exit 1
fi

echo "All repos up to date."
