#!/usr/bin/env bash
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
OUT="$WS/data/status/site-analytics.json"
mkdir -p "$WS/data/status"

ANALYTICS_SECRET="${ANALYTICS_SECRET:-}"
if [ -z "$ANALYTICS_SECRET" ] && [ -f "/home/jabbit/analytics/.env" ]; then
  # shellcheck disable=SC1091
  source /home/jabbit/analytics/.env || true
  ANALYTICS_SECRET="${ANALYTICS_SECRET:-}"
fi

if [ -z "$ANALYTICS_SECRET" ]; then
  jq -n --arg ts "$(date -Iseconds)" '{ok:false,last_check:$ts,error:"missing_analytics_secret"}' > "$OUT"
  echo "$OUT"
  exit 0
fi

RAW="$(curl -sS --max-time 10 "http://127.0.0.1:9000/stats?secret=${ANALYTICS_SECRET}" || true)"
if ! echo "$RAW" | jq -e . >/dev/null 2>&1; then
  jq -n --arg ts "$(date -Iseconds)" --arg raw "${RAW:0:400}" '{ok:false,last_check:$ts,error:"stats_unavailable",raw:$raw}' > "$OUT"
  echo "$OUT"
  exit 0
fi

echo "$RAW" | jq --arg ts "$(date -Iseconds)" '
  {
    ok: true,
    last_check: $ts,
    total_events: (.totalEvents // .total // 0),
    pageviews_total: (
      if (.eventCounts|type)=="object" then (.eventCounts.pageview // 0)
      else 0 end
    ),
    app_store_clicks_total: (
      if (.eventCounts|type)=="object" then (.eventCounts.app_store_click // 0)
      else 0 end
    ),
    today_pageviews: (
      if (.today|type)=="object" then (.today.pageview // 0)
      elif (.today|type)=="number" then .today
      else 0 end
    ),
    today_app_store_clicks: (
      if (.today|type)=="object" then (.today.app_store_click // 0) else 0 end
    ),
    yesterday_pageviews: (
      if (.yesterday|type)=="object" then (.yesterday.pageview // 0)
      elif (.yesterday|type)=="number" then .yesterday
      else 0 end
    ),
    yesterday_app_store_clicks: (
      if (.yesterday|type)=="object" then (.yesterday.app_store_click // 0) else 0 end
    ),
    top_pages: (.topPages // []),
    top_click_pages: (.topClickPages // [])
  }
' > "$OUT"

echo "$OUT"
