#!/usr/bin/env bash
set -euo pipefail

# Purpose: keep docs/send-now-pack-latest.txt in sync with the canonical send-now brief.
# This reduces friction for manual execution (copy/paste) when the loop is STOP'd by ready_to_send.

ROOT="/home/jabbit/.openclaw/workspace"
LEDGER="$ROOT/data/status/manual-growth-loop-ledger.json"
BRIEF_LINK="$ROOT/docs/distribution/send-now-brief-latest.md"
OUT="$ROOT/docs/send-now-pack-latest.txt"

# If there is nothing ready_to_send, do not churn this tracked file.
# (It’s only useful when the loop is STOP’d by a ready_to_send backlog.)
if [[ -f "$LEDGER" ]]; then
  ready_count=$(jq -r '[.sendQueues[]? | select(.status=="ready_to_send")] | length' "$LEDGER" 2>/dev/null || echo 0)
  if [[ "$ready_count" = "0" ]]; then
    echo "ok: ready_to_send=0; skipping $OUT refresh"
    exit 0
  fi
fi

if [[ ! -e "$BRIEF_LINK" ]]; then
  echo "ERR: missing send-now brief: $BRIEF_LINK" >&2
  exit 1
fi

# Rewrite only if content changed (avoid churn in hourly loops).
if [[ -f "$OUT" ]] && cmp -s "$BRIEF_LINK" "$OUT"; then
  echo "ok: $OUT already matches $BRIEF_LINK (no-op)"
  exit 0
fi

cat "$BRIEF_LINK" > "$OUT"
echo "ok: updated $OUT from $BRIEF_LINK"