#!/usr/bin/env bash
set -euo pipefail

LEDGER="${1:-/home/jabbit/.openclaw/workspace/data/status/manual-growth-loop-ledger.json}"
STATE="${2:-/home/jabbit/.openclaw/workspace/data/status/manual-growth-loop-stagnation.json}"

mkdir -p "$(dirname "$STATE")"

if [ ! -f "$STATE" ]; then
  echo '{"lastReadyCount":null,"streak":0,"lastUpdatedUtc":null}' > "$STATE"
fi

ready_count=$(jq '[.sendQueues[] | select(.status=="ready_to_send")] | length' "$LEDGER")
last_ready=$(jq -r '.lastReadyCount' "$STATE")
last_streak=$(jq -r '.streak' "$STATE")

if [ "$last_ready" = "null" ] || [ "$ready_count" -ne "$last_ready" ]; then
  streak=1
else
  streak=$((last_streak+1))
fi

now=$(date -u +%FT%TZ)

tmp=$(mktemp)
jq --argjson rc "$ready_count" --argjson st "$streak" --arg now "$now" '.lastReadyCount=$rc | .streak=$st | .lastUpdatedUtc=$now' "$STATE" > "$tmp"
mv "$tmp" "$STATE"

# Output is designed to be machine/cron friendly.
# 0: ok, 10: stale-ready-to-send (human action needed)
if [ "$ready_count" -gt 0 ] && [ "$streak" -ge 4 ]; then
  echo "stagnation: STALE_READY_TO_SEND"
  echo "ready_to_send_count: $ready_count"
  echo "streak: $streak"
  exit 10
fi

echo "stagnation: ok"
echo "ready_to_send_count: $ready_count"
echo "streak: $streak"
