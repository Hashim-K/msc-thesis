#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_LAUNCHER="$ROOT/repos/mir-desktop-app/run.sh"

if [[ ! -x "$APP_LAUNCHER" ]]; then
  printf 'Desktop launcher is missing or not executable: %s\n' "$APP_LAUNCHER" >&2
  printf 'Initialize or update the mir-desktop-app submodule first.\n' >&2
  exit 1
fi

exec "$APP_LAUNCHER" "$@"
