#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT/.env" ] && source "$ROOT/.env"
exec python "$ROOT/repos/mir-webapp/training_webapp.py" "$@"
