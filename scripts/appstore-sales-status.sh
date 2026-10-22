#!/usr/bin/env bash
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
OUT="$WS/data/status/appstore-sales.json"
mkdir -p "$WS/data/status"

# App Store creds live outside the repo: ~/.secrets/appstore.env (mode 600). No repo-dir fallback.
if [ -f "$HOME/.secrets/appstore.env" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$HOME/.secrets/appstore.env" || true
  set +a
fi

TMP="$(mktemp "$WS/data/status/.appstore-sales.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

RAW="$(python3 "$WS/scripts/appstore-sales.py" --json 2>/dev/null || true)"
if ! echo "$RAW" | jq -e . >/dev/null 2>&1; then
  jq -n --arg ts "$(date -Iseconds)" --arg raw "${RAW:0:400}" '{ok:false,last_check:$ts,error:"appstore_sales_unavailable",raw:$raw}' > "$TMP"
  mv "$TMP" "$OUT"
  echo "$OUT"
  exit 0
fi

# day_status: "report" (Apple file with N units), "no_sales" (Apple 404 "There were no
# sales for the date specified."), or "not_published" (Apple 404 "Report is not available
# yet", i.e. before the next-day availability time). units = new downloads only.
echo "$RAW" | jq --arg ts "$(date -Iseconds)" '
  . as $r
  | {
      ok: ($r.ok // false),
      last_check: $ts,
      metric: ($r.metric // "sales_reports_units"),
      day_status: ($r.day_status // "unknown"),
      summary: ($r.summary // null),
      provisional: ($r.provisional // false),
      report_date: ($r.report_date // null),
      units: ($r.units // 0),
      units_definition: ($r.units_definition // null),
      units_all: ($r.units_all // 0),
      redownloads: ($r.redownloads // 0),
      updates: ($r.updates // 0),
      iap_units: ($r.iap_units // 0),
      revenue_usd: ($r.revenue_usd // 0),
      proceeds_by_currency: ($r.proceeds_by_currency // {}),
      apple_detail: ($r.apple_detail // null),
      pending_dates: ($r.pending_dates // []),
      days: [($r.days // [])[] | {date, status, http, apple_code, apple_detail, provisional, downloads, redownloads, updates, iap_units, units_all} | with_entries(select(.value != null))],
      timestamp: ($r.timestamp // null)
    }
  | .suspect_reasons = (
      []
      + (if (.ok != true) then ["fetch_failed"] else [] end)
      + (if (.report_date == null) then ["missing_report_date"] else [] end)
      + (if ((.units|tonumber) < 0) then ["negative_units"] else [] end)
    )
  | .suspect = (.suspect_reasons | length > 0)
' > "$TMP"
mv "$TMP" "$OUT"

echo "$OUT"
