#!/usr/bin/env bash
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
TODAY="$(date -u +%Y-%m-%d)"
KPI="$WS/docs/kpi-${TODAY}.md"
SITE="$WS/data/status/site-analytics.json"
APPSTORE="$WS/data/status/appstore-sales.json"
REDDIT="$WS/data/status/reddit-daily-check.json"
DIST="$WS/data/status/distribution-daily-check.json"

pct() {
  local num="${1:-0}"
  local den="${2:-0}"
  awk -v n="$num" -v d="$den" 'BEGIN { if (d<=0) print "0.0%"; else printf "%.1f%%", (100*n/d) }'
}

jq_field() {
  local file="$1"
  local expr="$2"
  local fallback="${3:-unknown}"
  if [ -f "$file" ]; then
    jq -r "$expr // \"$fallback\"" "$file" 2>/dev/null || printf '%s\n' "$fallback"
  else
    printf '%s\n' "$fallback"
  fi
}

if [ -x "$WS/scripts/generate-kpi-dashboard.sh" ]; then
  bash "$WS/scripts/generate-kpi-dashboard.sh" >/dev/null
fi

site_status="$(jq_field "$SITE" '.status' 'BROKEN')"
site_suspect_reasons="$(jq_field "$SITE" '(.suspect_reasons // []) | join(", ")' '')"
today_views="$(jq_field "$SITE" '.today_pageviews' '0')"
today_clicks="$(jq_field "$SITE" '.today_app_store_clicks' '0')"
yday_views="$(jq_field "$SITE" '.yesterday_pageviews' '0')"
yday_clicks="$(jq_field "$SITE" '.yesterday_app_store_clicks' '0')"
total_views="$(jq_field "$SITE" '.pageviews_total' '0')"
total_clicks="$(jq_field "$SITE" '.app_store_clicks_total' '0')"
top_views="$(jq_field "$SITE" '[.top_pageviews[]? | (.page // "?") + " (" + ((.count // 0)|tostring) + ")"] | .[0:3] | join(", ")' 'n/a')"
top_clicks="$(jq_field "$SITE" '[.top_click_pages[]? | (.page // "?") + " (" + ((.count // 0)|tostring) + ")"] | .[0:3] | join(", ")' 'n/a')"

app_ok="$(jq_field "$APPSTORE" '.ok' 'false')"
app_date="$(jq_field "$APPSTORE" '.report_date' 'unknown')"
app_units="$(jq_field "$APPSTORE" '.units' 'unknown')"
app_revenue="$(jq_field "$APPSTORE" '.revenue_usd' 'unknown')"
app_suspect="$(jq_field "$APPSTORE" '.suspect' 'false')"
app_suspect_reasons="$(jq_field "$APPSTORE" '(.suspect_reasons // []) | join(", ")' '')"

reddit_status="unknown"
if [ -f "$REDDIT" ]; then
  reddit_status="$(jq -r 'if (.posted == true) then "posted" elif ((.skip_reason // "") | length) > 0 then "skipped" else "unconfirmed" end' "$REDDIT" 2>/dev/null || echo unknown)"
fi

dist_status="unknown"
if [ -f "$DIST" ]; then
  dist_status="$(jq -r 'if (.executed == true) then "executed" elif ((.skip_reason // "") | test("sender identity mismatch"; "i")) then "blocked: sender identity mismatch" elif ((.skip_reason // "") | length) > 0 then "skipped" else "unconfirmed" end' "$DIST" 2>/dev/null || echo unknown)"
fi

today_ctr="$(pct "$today_clicks" "$today_views")"
yday_ctr="$(pct "$yday_clicks" "$yday_views")"
total_ctr="$(pct "$total_clicks" "$total_views")"

site_line="Site: today ${today_views} views / ${today_clicks} App Store clicks (${today_ctr}); yesterday ${yday_views} / ${yday_clicks} (${yday_ctr}); total ${total_views} / ${total_clicks} (${total_ctr})."
if [ "$site_status" != "OK" ]; then
  site_line="${site_line} Analytics status: ${site_status}${site_suspect_reasons:+ (${site_suspect_reasons})}."
fi

app_line="Installs: ${app_units} App Store units on report date ${app_date}; revenue ${app_revenue}."
if [ "$app_ok" != "true" ] || [ "$app_suspect" = "true" ]; then
  app_line="${app_line} App Store status needs attention${app_suspect_reasons:+ (${app_suspect_reasons})}."
fi

focus="$(awk -v tv="$today_views" -v tc="$today_clicks" -v yv="$yday_views" -v yc="$yday_clicks" 'BEGIN {
  if (tv + 0 == 0) print "Reality: no tracked site traffic today yet, so the bottleneck is traffic acquisition, not page conversion.";
  else if (tc + 0 == 0) print "Reality: traffic exists but no App Store clicks today, so the immediate bottleneck is qualified intent or CTA conversion.";
  else if (tc + 0 > yc + 0) print "Reality: App Store clicks improved vs yesterday; keep pressure on the pages producing intent.";
  else print "Reality: traffic is still thin; do not overread CTR until volume improves.";
}')"

cat <<EOF
Daily traffic update - ${TODAY}

${app_line}
${site_line}
Top view pages: ${top_views}
Top click pages: ${top_clicks}
${focus}

Execution blockers: Reddit ${reddit_status}; distribution ${dist_status}.
KPI file: ${KPI}
EOF
