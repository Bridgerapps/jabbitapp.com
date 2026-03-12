#!/usr/bin/env bash
set -euo pipefail

# Rate-limited wrapper around escalate-stale-ready.sh
# Purpose: prevent endless churn of new escalation briefs when the queue is stuck.

ROOT="/home/jabbit/.openclaw/workspace"
LEDGER="${1:-$ROOT/data/status/manual-growth-loop-ledger.json}"
STATE="$ROOT/data/status/manual-growth-loop-escalation-state.json"

need() { [ -f "$1" ] || { echo "missing: $1" >&2; exit 1; }; }
need "$LEDGER"

mkdir -p "$(dirname "$STATE")"

if [ ! -f "$STATE" ]; then
  printf '{"lastEscalationUtc":null}\n' > "$STATE"
fi

min_interval_sec="${MIN_INTERVAL_SECONDS:-21600}" # default: 6h

last=$(jq -r '.lastEscalationUtc // empty' "$STATE" 2>/dev/null || true)
now_epoch=$(date -u +%s)

last_epoch=0
if [ -n "$last" ] && [ "$last" != "null" ]; then
  # Prefer coreutils date over python for portability in cron shells.
  last_epoch=$(date -u -d "$last" +%s 2>/dev/null || echo 0)
fi

age=$((now_epoch-last_epoch))
if [ "$last_epoch" -gt 0 ] && [ "$age" -lt "$min_interval_sec" ]; then
  echo "SKIP: escalation rate-limited (last=${last}, age=${age}s < ${min_interval_sec}s)"
  exit 0
fi

# Run escalation (it will decide based on THRESHOLD_SEC whether to write anything)
out=$(bash "$ROOT/scripts/manual-growth-loop/escalate-stale-ready.sh" "$LEDGER") || exit $?

# Only update state if an escalation brief was actually written.
if echo "$out" | grep -q '^WROTE:'; then
  now_utc=$(date -u +%FT%TZ)
  tmp=$(mktemp)
  jq --arg t "$now_utc" '.lastEscalationUtc=$t' "$STATE" > "$tmp" && mv "$tmp" "$STATE"
fi

echo "$out"