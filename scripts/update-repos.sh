#!/usr/bin/env bash
# update-repos.sh — pull latest on every submodule and update SHA pins
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
 
echo "==> Fetching and fast-forwarding all submodules..."
(
  cd "$ROOT"
  git submodule foreach \
    'git fetch -q origin && \
     BRANCH=$(git rev-parse --abbrev-ref HEAD) && \
     if [ "$BRANCH" = "HEAD" ]; then \
       echo "  $name: detached HEAD, skipping"; \
     else \
       git merge --ff-only origin/$BRANCH && echo "  $name: updated" || echo "  $name: cannot fast-forward, skipping"; \
     fi'
)
 
echo "==> Staging updated submodule SHAs..."
(
  cd "$ROOT"
  git add repos/
  if git diff --cached --quiet; then
    echo "    No SHA changes to commit."
  else
    git commit -m "chore: sync submodule SHAs"
    echo "    SHA update committed. Run: git push"
  fi
)
 
echo "Done."
