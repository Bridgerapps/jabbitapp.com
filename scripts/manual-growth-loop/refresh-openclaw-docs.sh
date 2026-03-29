#!/usr/bin/env bash
set -euo pipefail

# refresh-openclaw-docs.sh
# Purpose: keep a small, local, inspectable cache of key OpenClaw operator docs.
# Safe: read-only HTTP fetches to known OpenClaw domains; writes under data/status/.

ROOT="/home/jabbit/.openclaw/workspace"
OUTDIR="$ROOT/data/status/openclaw-doc-cache"
TTL_HOURS="${TTL_HOURS:-72}"

mkdir -p "$OUTDIR"

now_epoch=$(date -u +%s)

ts_utc=$(date -u +%Y-%m-%dT%H%M%SZ)

fetch() {
  local name="$1"
  local url="$2"
  local out="$OUTDIR/${name}.html"
  local meta="$OUTDIR/${name}.meta.json"

  local do_fetch=1
  if [ -f "$meta" ]; then
    local last_epoch
    last_epoch=$(jq -r '.fetched_epoch // 0' "$meta" 2>/dev/null || echo 0)
    local age_hours=$(( (now_epoch - last_epoch) / 3600 ))
    if [ "$age_hours" -lt "$TTL_HOURS" ]; then
      do_fetch=0
    fi
  fi

  if [ "$do_fetch" = "1" ]; then
    curl -fsSL --max-time 20 -A "openclaw-manual-growth-loop/1.0" "$url" -o "$out" || return 0
    {
      echo "{"
      echo "  \"name\": \"$name\","
      echo "  \"url\": \"$url\","
      echo "  \"fetched_utc\": \"$ts_utc\","
      echo "  \"fetched_epoch\": $now_epoch"
      echo "}"
    } >"$meta"
  fi
}

# Keep this list small + stable (avoid rate-limit churn).
fetch "cron-jobs" "https://openclawlab.com/en/docs/automation/cron-jobs/" || true
fetch "cron-vs-heartbeat" "https://openclawlab.com/en/docs/automation/cron-vs-heartbeat/" || true

# Also cache a known troubleshooting post used in prior self-improvement runs.
fetch "silent-delivery" "https://dev.to/arezvov/openclaw-troubleshooting-no-reply-from-agent-workflowautomd-and-silent-delivery-failures-9jn" || true

echo "openclaw-doc-cache: ok ($OUTDIR)"