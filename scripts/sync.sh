#!/usr/bin/env bash
# sync.sh — pull latest on every submodule and update SHA pins
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
 
echo "==> Fetching and fast-forwarding all submodules..."
git -C "$ROOT" submodule foreach \
  'git fetch -q origin && \
   BRANCH=$(git rev-parse --abbrev-ref HEAD) && \
   if [ "$BRANCH" = "HEAD" ]; then \
     echo "  $name: detached HEAD, skipping"; \
   else \
     git merge --ff-only origin/$BRANCH && echo "  $name: updated" || echo "  $name: cannot fast-forward, skipping"; \
   fi'
 
echo "==> Staging updated submodule SHAs..."
git -C "$ROOT" add repos/
if git -C "$ROOT" diff --cached --quiet; then
  echo "    No SHA changes to commit."
else
  git -C "$ROOT" commit -m "chore: sync submodule SHAs"
  echo "    SHA update committed. Run: git push"
fi
 
echo "Done."
