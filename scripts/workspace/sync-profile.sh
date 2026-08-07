#!/usr/bin/env bash
# sync-profile.sh - initialize and fast-forward only the submodules needed by a workspace profile
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
profile="${MIR_WORKSPACE_PROFILE:-runner}"
pull_root=false
deinit_others=false

usage() {
  cat <<'EOF'
Usage: ./scripts/workspace/sync-profile.sh [--profile runner|webapp|full] [--pull-root] [--deinit-others]

Profiles:
  runner  Code/data needed for training and DVC materialization.
  webapp  runner plus the scheduling and completed-results webapps.
  full    All top-level submodules from .gitmodules.

Options:
  --pull-root      Fast-forward the msc-thesis superproject before syncing submodules.
  --deinit-others  Deinitialize clean submodules that are not part of the selected profile.

The script is intentionally conservative: it uses fast-forward merges only,
never resets an initialized submodule to an older superproject pin, and skips
tracked local changes, ahead branches, diverged branches, or otherwise unsafe
worktrees. Untracked runtime outputs are preserved; Git still rejects any
checkout that would overwrite one.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      profile="${2:-}"
      shift 2
      ;;
    --pull-root)
      pull_root=true
      shift
      ;;
    --deinit-others)
      deinit_others=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

profile_paths() {
  case "$profile" in
    runner)
      cat <<'EOF'
repos/mir-core
repos/mir-train-hpc
repos/mir-local-cluster
repos/mir-data
repos/mir-outputs
repos/mir-environment
EOF
      ;;
    webapp)
      cat <<'EOF'
repos/mir-core
repos/mir-train-hpc
repos/mir-local-cluster
repos/mir-data
repos/mir-outputs
repos/mir-environment
repos/mir-webapp
repos/mir-results-webapp
EOF
      ;;
    full)
      git -C "$ROOT" config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}'
      ;;
    *)
      echo "Unknown workspace profile: $profile" >&2
      exit 1
      ;;
  esac
}

submodule_branch() {
  local path="$1"
  local name
  name="$(git -C "$ROOT" config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk -v path="$path" '$2 == path {print $1; exit}')"
  name="${name#submodule.}"
  name="${name%.path}"
  git -C "$ROOT" config -f .gitmodules --get "submodule.${name}.branch" 2>/dev/null || echo "main"
}

has_tracked_changes() {
  local path="$1"
  [[ -n "$(git -C "$path" status --porcelain --untracked-files=no 2>/dev/null)" ]]
}

is_dirty() {
  local path="$1"
  [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]
}

pull_worktree() {
  local path="$1"
  local label="$2"
  local wanted_branch="${3:-main}"
  local allow_tracked_changes="${4:-false}"

  echo "==> $label"
  if ! git -C "$path" rev-parse --git-dir >/dev/null 2>&1; then
    echo "    skip: not a git repository"
    return 1
  fi

  if has_tracked_changes "$path"; then
    if [[ "$allow_tracked_changes" != true ]]; then
      echo "    skip: worktree has tracked local changes"
      return 1
    fi
    echo "    note: preserving tracked deployment overrides"
  fi

  local branch
  branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
  if [[ "$branch" != "$wanted_branch" ]]; then
    if [[ "$branch" == "HEAD" ]]; then
      echo "    detached HEAD - checking out $wanted_branch"
    else
      echo "    branch $branch - checking out $wanted_branch"
    fi
    if ! git -C "$path" checkout "$wanted_branch" >/dev/null 2>&1; then
      echo "    failed to checkout $wanted_branch"
      return 1
    fi
    branch="$wanted_branch"
  fi

  if ! git -C "$path" fetch --quiet --prune origin; then
    echo "    failed: fetch origin"
    return 1
  fi

  if ! git -C "$path" rev-parse --verify --quiet "origin/$branch" >/dev/null; then
    echo "    skip: origin/$branch does not exist"
    return 1
  fi

  local ahead behind
  read -r ahead behind < <(git -C "$path" rev-list --left-right --count "HEAD...origin/$branch")
  if (( ahead > 0 && behind > 0 )); then
    echo "    skip: branch diverged from origin/$branch"
    return 1
  fi
  if (( ahead > 0 )); then
    echo "    skip: $ahead local-only commit(s)"
    return 1
  fi

  if git -C "$path" merge --ff-only "origin/$branch" >/dev/null; then
    echo "    ok"
    echo "    latest commit: $(git -C "$path" log -1 --format='%h - %s')"
    return 0
  fi

  echo "    failed: cannot fast-forward"
  return 1
}

deinit_non_profile_submodules() {
  local keep_file="$1"
  local path

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    if grep -Fxq "$path" "$keep_file"; then
      continue
    fi
    if [[ ! -e "$ROOT/$path/.git" ]]; then
      continue
    fi
    if is_dirty "$ROOT/$path"; then
      echo "==> $path"
      echo "    keep: non-profile submodule has local changes"
      continue
    fi
    echo "==> deinit $path"
    git -C "$ROOT" submodule deinit -f -- "$path" >/dev/null
  done < <(git -C "$ROOT" config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')
}

mapfile -t paths < <(profile_paths)
if (( ${#paths[@]} == 0 )); then
  echo "Profile $profile has no submodules"
  exit 1
fi

failures=()
synced=()

if $pull_root; then
  if pull_worktree "$ROOT" "msc-thesis" "$(git -C "$ROOT" branch --show-current || echo main)" true; then
    synced+=("msc-thesis")
  else
    failures+=("msc-thesis")
  fi
  echo
fi

echo "==> Workspace profile: $profile"
printf '    %s\n' "${paths[@]}"
echo

git -C "$ROOT" submodule sync --recursive -- "${paths[@]}" >/dev/null
git -C "$ROOT" submodule init -- "${paths[@]}" >/dev/null

for path in "${paths[@]}"; do
  if [[ -e "$ROOT/$path/.git" ]]; then
    continue
  fi
  echo "==> initialize $path"
  if ! git -C "$ROOT" submodule update --init --recursive -- "$path"; then
    echo "    failed to initialize submodule"
    failures+=("$path")
  fi
  echo
done

for path in "${paths[@]}"; do
  branch="$(submodule_branch "$path")"
  if pull_worktree "$ROOT/$path" "$path" "$branch"; then
    synced+=("$path")
  else
    failures+=("$path")
  fi
  echo
done

if $deinit_others; then
  keep_file="$(mktemp)"
  printf '%s\n' "${paths[@]}" > "$keep_file"
  deinit_non_profile_submodules "$keep_file"
  rm -f "$keep_file"
fi

if (( ${#failures[@]} > 0 )); then
  echo "Failures/skips:"
  printf '  - %s\n' "${failures[@]}"
  printf '__MIR_WORKSPACE_SYNC_SUMMARY__=%s|%s|%s\n' "$profile" "${#synced[@]}" "${#failures[@]}"
  exit 1
fi

printf '__MIR_WORKSPACE_SYNC_SUMMARY__=%s|%s|0\n' "$profile" "${#synced[@]}"
echo "Workspace profile '$profile' is up to date."
