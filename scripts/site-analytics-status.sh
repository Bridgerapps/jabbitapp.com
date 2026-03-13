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

# Best-effort: ensure the local analytics service is running before querying it.
if [ -x "$WS/scripts/analytics-server-ensure.sh" ]; then
  bash "$WS/scripts/analytics-server-ensure.sh" >/dev/null 2>&1 || true
fi

RAW="$(curl -sS --max-time 10 "http://127.0.0.1:9000/stats?secret=${ANALYTICS_SECRET}" || true)"
if ! echo "$RAW" | jq -e . >/dev/null 2>&1; then
  jq -n --arg ts "$(date -Iseconds)" --arg raw "${RAW:0:400}" '{ok:false,last_check:$ts,error:"stats_unavailable",raw:$raw}' > "$OUT"
  echo "$OUT"
  exit 0
fi

echo "$RAW" | jq --arg ts "$(date -Iseconds)" '
  def _unique_pages(arr): [arr[]? | .page? // empty] | unique;
  def _suspect_reasons(total_events; top_pages):
    (
      []
      + (if (total_events|tonumber) < 10 then ["low_total_events(<10)"] else [] end)
      + (
          if (_unique_pages(top_pages) | length) == 1 and (_unique_pages(top_pages)[0] == "/") then
            ["only_root_page_seen"]
          else [] end
        )
    );

  . as $raw
  | (
      {
        ok: true,
        last_check: $ts,
        total_events: ($raw.totalEvents // $raw.total // 0),
        pageviews_total: (
          if ($raw.eventCounts|type)=="object" then ($raw.eventCounts.pageview // 0)
          else 0 end
        ),
        app_store_clicks_total: (
          if ($raw.eventCounts|type)=="object" then ($raw.eventCounts.app_store_click // 0)
          else 0 end
        ),
        today_pageviews: (
          if ($raw.today|type)=="object" then ($raw.today.pageview // 0)
          elif ($raw.today|type)=="number" then $raw.today
          else 0 end
        ),
        today_app_store_clicks: (
          if ($raw.today|type)=="object" then ($raw.today.app_store_click // 0) else 0 end
        ),
        yesterday_pageviews: (
          if ($raw.yesterday|type)=="object" then ($raw.yesterday.pageview // 0)
          elif ($raw.yesterday|type)=="number" then $raw.yesterday
          else 0 end
        ),
        yesterday_app_store_clicks: (
          if ($raw.yesterday|type)=="object" then ($raw.yesterday.app_store_click // 0) else 0 end
        ),
        top_pages: ($raw.topPages // []),
        top_pageviews: ($raw.topPageviews // $raw.topPages // []),
        top_click_pages: ($raw.topClickPages // [])
      }
      | .suspect_reasons = _suspect_reasons(.total_events; .top_pages)
      | .suspect = (.suspect_reasons | length > 0)
    )
' > "$OUT"

echo "$OUT"
