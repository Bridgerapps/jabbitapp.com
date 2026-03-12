#!/usr/bin/env bash
set -euo pipefail

# Purpose: keep docs/send-now-pack-latest.txt in sync with the canonical send-now brief.
# This reduces friction for manual execution (copy/paste) when the loop is STOP'd by ready_to_send.

ROOT="/home/jabbit/.openclaw/workspace"
BRIEF_LINK="$ROOT/docs/distribution/send-now-brief-latest.md"
OUT="$ROOT/docs/send-now-pack-latest.txt"

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