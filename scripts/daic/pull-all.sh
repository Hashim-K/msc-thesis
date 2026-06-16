#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="${MIR_WORKSPACE_PROFILE:-runner}"

exec "$ROOT/scripts/workspace/sync-profile.sh" --profile "$PROFILE" --pull-root
