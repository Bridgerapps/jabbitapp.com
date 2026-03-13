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
  printf '{"lastEscalationUtc":null,"lastLedgerFingerprint":null}\n' > "$STATE"
fi

min_interval_sec="${MIN_INTERVAL_SECONDS:-21600}" # default: 6h

last=$(jq -r '.lastEscalationUtc // empty' "$STATE" 2>/dev/null || true)
last_fp=$(jq -r '.lastLedgerFingerprint // empty' "$STATE" 2>/dev/null || true)
now_epoch=$(date -u +%s)

# Compute current ledger fingerprint; if the queue hasn't changed since last escalation,
# don't generate a new brief even if the time window elapsed.
cur_fp=$(jq -c '.sendQueues | sort_by(.leadId, .whenUtc, .status, .channel, .to, (.subject // ""))' "$LEDGER" | sha256sum | awk '{print $1}')

if [ -n "$last_fp" ] && [ "$last_fp" != "null" ] && [ "$last_fp" = "$cur_fp" ]; then
  echo "SKIP: ledger unchanged since last escalation (fingerprint=$cur_fp)"
  exit 0
fi

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
  jq --arg t "$now_utc" --arg fp "$cur_fp" '.lastEscalationUtc=$t | .lastLedgerFingerprint=$fp' "$STATE" > "$tmp" && mv "$tmp" "$STATE"
fi

echo "$out"