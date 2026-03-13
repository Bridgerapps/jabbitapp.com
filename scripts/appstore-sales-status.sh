#!/usr/bin/env bash
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
OUT="$WS/data/status/appstore-sales.json"
mkdir -p "$WS/data/status"

RAW="$(python3 "$WS/scripts/appstore-sales.py" --json 2>/dev/null || true)"
if ! echo "$RAW" | jq -e . >/dev/null 2>&1; then
  jq -n --arg ts "$(date -Iseconds)" --arg raw "${RAW:0:400}" '{ok:false,last_check:$ts,error:"appstore_sales_unavailable",raw:$raw}' > "$OUT"
  echo "$OUT"
  exit 0
fi

echo "$RAW" | jq --arg ts "$(date -Iseconds)" '
  . as $r
  | {
      ok: true,
      last_check: $ts,
      metric: ($r.metric // "sales_reports_units"),
      report_date: ($r.report_date // null),
      units: ($r.units // 0),
      revenue_usd: ($r.revenue_usd // 0),
      timestamp: ($r.timestamp // null)
    }
  | .suspect_reasons = (
      []
      + (if (.report_date == null) then ["missing_report_date"] else [] end)
      + (if ((.units|tonumber) < 0) then ["negative_units"] else [] end)
    )
  | .suspect = (.suspect_reasons | length > 0)
' > "$OUT"

echo "$OUT"
