#!/usr/bin/env bash
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
TODAY="$(date -u +%Y-%m-%d)"
OUT="$WS/docs/kpi-${TODAY}.md"

FORCE=false
if [[ "${1:-}" == "--force" ]]; then
  FORCE=true
fi

if [[ -f "$OUT" && "$FORCE" != "true" ]]; then
  echo "kpi:exists:$OUT"
  exit 0
fi

if [[ ! -x "$WS/scripts/generate-kpi-dashboard.sh" ]]; then
  echo "kpi:error:missing_generate_script" >&2
  exit 1
fi

bash "$WS/scripts/generate-kpi-dashboard.sh" >/dev/null

if [[ -f "$OUT" ]]; then
  echo "kpi:ok:$OUT"
else
  echo "kpi:error:not_created:$OUT" >&2
  exit 1
fi
