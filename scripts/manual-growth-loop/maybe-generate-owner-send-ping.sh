#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/jabbit/.openclaw/workspace"
OUT_FILE="${OUT_FILE:-$ROOT/data/status/owner-send-ping-latest.txt}"

# Rate-limit so we don't churn artifacts every hour.
MIN_INTERVAL_SECONDS="${MIN_INTERVAL_SECONDS:-21600}" # 6h
LIMIT="${LIMIT:-3}"

mkdir -p "$(dirname "$OUT_FILE")"

now_epoch=$(date -u +%s)
last_epoch=0
if [ -f "$OUT_FILE" ]; then
  # GNU stat on Linux
  last_epoch=$(stat -c %Y "$OUT_FILE" 2>/dev/null || echo 0)
fi

age=$(( now_epoch - last_epoch ))
if [ "$last_epoch" -ne 0 ] && [ "$age" -lt "$MIN_INTERVAL_SECONDS" ]; then
  echo "SKIP: owner-send-ping is fresh (age=${age}s < ${MIN_INTERVAL_SECONDS}s)"
  exit 0
fi

# Refresh the curated awaiting_owner shortlist first (cheap, reduces owner confusion)
# Only if we have a ledger (no-op if missing).
if [ -f "$ROOT/data/status/manual-growth-loop-ledger.json" ]; then
  OUT_DIR="$(dirname "$OUT_FILE")" LIMIT="$LIMIT" \
    "$ROOT/scripts/manual-growth-loop/generate-awaiting-owner-top3.sh" >/dev/null 2>&1 || true
fi

OUT_DIR="$(dirname "$OUT_FILE")" OUT_FILE="$OUT_FILE" LIMIT="$LIMIT" \
  "$ROOT/scripts/manual-growth-loop/generate-owner-send-ping.sh" >/dev/null

echo "OK: refreshed owner-send-ping ($OUT_FILE)"