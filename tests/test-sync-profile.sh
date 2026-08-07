#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d /tmp/msc-sync-profile-test.XXXXXX)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

export GIT_AUTHOR_NAME="MIR sync test"
export GIT_AUTHOR_EMAIL="sync-test@example.invalid"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
export GIT_ALLOW_PROTOCOL=file

CHILD_SOURCE="$TEST_ROOT/child-source"
CHILD_REMOTE="$TEST_ROOT/child.git"
SUPER_SOURCE="$TEST_ROOT/super-source"
SUPER_REMOTE="$TEST_ROOT/super.git"
WORKTREE="$TEST_ROOT/worktree"

git init -q -b main "$CHILD_SOURCE"
printf 'child-v1\n' > "$CHILD_SOURCE/version.txt"
git -C "$CHILD_SOURCE" add version.txt
git -C "$CHILD_SOURCE" commit -q -m "child v1"
git clone -q --bare "$CHILD_SOURCE" "$CHILD_REMOTE"
git -C "$CHILD_SOURCE" remote add origin "$CHILD_REMOTE"

git init -q -b main "$SUPER_SOURCE"
mkdir -p "$SUPER_SOURCE/scripts/workspace"
cp "$SOURCE_ROOT/scripts/workspace/sync-profile.sh" \
  "$SUPER_SOURCE/scripts/workspace/sync-profile.sh"
chmod +x "$SUPER_SOURCE/scripts/workspace/sync-profile.sh"
printf 'tracked-default\n' > "$SUPER_SOURCE/.env"
printf 'root-v1\n' > "$SUPER_SOURCE/README.md"
git -C "$SUPER_SOURCE" add .env README.md scripts/workspace/sync-profile.sh
git -C "$SUPER_SOURCE" commit -q -m "superproject v1"
git -C "$SUPER_SOURCE" submodule add -q "$CHILD_REMOTE" repos/child
git -C "$SUPER_SOURCE" config -f .gitmodules submodule.repos/child.branch main
git -C "$SUPER_SOURCE" add .gitmodules repos/child
git -C "$SUPER_SOURCE" commit -q -m "register child"
git clone -q --bare "$SUPER_SOURCE" "$SUPER_REMOTE"
git -C "$SUPER_SOURCE" remote add origin "$SUPER_REMOTE"

git clone -q --recurse-submodules "$SUPER_REMOTE" "$WORKTREE"
printf 'host-specific-value\n' > "$WORKTREE/.env"
mkdir -p "$WORKTREE/repos/child/slurm"
printf 'runtime output\n' > "$WORKTREE/repos/child/slurm/job.out"

printf 'child-v2\n' > "$CHILD_SOURCE/version.txt"
git -C "$CHILD_SOURCE" add version.txt
git -C "$CHILD_SOURCE" commit -q -m "child v2"
git -C "$CHILD_SOURCE" push -q origin main

printf 'root-v2\n' >> "$SUPER_SOURCE/README.md"
git -C "$SUPER_SOURCE" add README.md
git -C "$SUPER_SOURCE" commit -q -m "superproject v2"
git -C "$SUPER_SOURCE" push -q origin main

"$WORKTREE/scripts/workspace/sync-profile.sh" --profile full --pull-root \
  > "$TEST_ROOT/first-sync.log"

test "$(git -C "$WORKTREE" rev-parse HEAD)" = \
  "$(git -C "$SUPER_REMOTE" rev-parse main)"
test "$(git -C "$WORKTREE/repos/child" rev-parse HEAD)" = \
  "$(git -C "$CHILD_REMOTE" rev-parse main)"
test "$(git -C "$WORKTREE/repos/child" branch --show-current)" = main
test "$(cat "$WORKTREE/.env")" = host-specific-value
test "$(cat "$WORKTREE/repos/child/slurm/job.out")" = "runtime output"

printf 'local tracked edit\n' > "$WORKTREE/repos/child/version.txt"
printf 'child-v3\n' > "$CHILD_SOURCE/version.txt"
git -C "$CHILD_SOURCE" add version.txt
git -C "$CHILD_SOURCE" commit -q -m "child v3"
git -C "$CHILD_SOURCE" push -q origin main
child_v2="$(git -C "$WORKTREE/repos/child" rev-parse HEAD)"

if "$WORKTREE/scripts/workspace/sync-profile.sh" --profile full \
  > "$TEST_ROOT/dirty-sync.log" 2>&1; then
  echo "expected a tracked child edit to block synchronization" >&2
  exit 1
fi

test "$(git -C "$WORKTREE/repos/child" rev-parse HEAD)" = "$child_v2"
test "$(cat "$WORKTREE/repos/child/version.txt")" = "local tracked edit"
grep -Fq "skip: worktree has tracked local changes" "$TEST_ROOT/dirty-sync.log"
grep -Fq "__MIR_WORKSPACE_SYNC_SUMMARY__=full|0|1" "$TEST_ROOT/dirty-sync.log"

echo "sync-profile regression test passed"
