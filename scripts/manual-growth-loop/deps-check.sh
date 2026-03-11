#!/usr/bin/env bash
set -euo pipefail

# Purpose: fail fast with a clear message if common dependencies are missing.
# This prevents silent partial runs in cron/self-improvement loops.

need_bin() {
  local b="$1"
  if ! command -v "$b" >/dev/null 2>&1; then
    echo "ERR: missing dependency: $b" >&2
    return 1
  fi
}

need_bin node
need_bin jq
need_bin date

echo "deps: ok (node=$(node -v), jq=$(jq --version 2>/dev/null || echo jq), date=$(date -u +%FT%TZ))"