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
  webapp  runner plus the FastAPI/Next.js webapp.
  full    All top-level submodules from .gitmodules.

Options:
  --pull-root      Fast-forward the msc-thesis superproject before syncing submodules.
  --deinit-others  Deinitialize clean submodules that are not part of the selected profile.

The script is intentionally conservative: it uses fast-forward merges only and
skips dirty, ahead, diverged, or otherwise unsafe worktrees instead of resetting
them.
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

is_dirty() {
  local path="$1"
  [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]
}

pull_worktree() {
  local path="$1"
  local label="$2"
  local wanted_branch="${3:-main}"

  echo "==> $label"
  if ! git -C "$path" rev-parse --git-dir >/dev/null 2>&1; then
    echo "    skip: not a git repository"
    return 1
  fi

  if is_dirty "$path"; then
    echo "    skip: worktree has local changes"
    return 1
  fi

  local branch
  branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
  if [[ "$branch" == "HEAD" ]]; then
    echo "    detached HEAD - checking out $wanted_branch"
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

if $pull_root; then
  pull_worktree "$ROOT" "msc-thesis" "$(git -C "$ROOT" branch --show-current || echo main)" || failures+=("msc-thesis")
  echo
fi

echo "==> Workspace profile: $profile"
printf '    %s\n' "${paths[@]}"
echo

(
  cd "$ROOT"
  git submodule sync --recursive -- "${paths[@]}" >/dev/null
  git submodule update --init --recursive -- "${paths[@]}"
)

for path in "${paths[@]}"; do
  branch="$(submodule_branch "$path")"
  pull_worktree "$ROOT/$path" "$path" "$branch" || failures+=("$path")
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
  exit 1
fi

echo "Workspace profile '$profile' is up to date."
