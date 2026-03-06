#!/usr/bin/env bash
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
OUT="$WS/docs/kpi-$(date -u +%Y-%m-%d).md"
NOW="$(date -u '+%Y-%m-%d %H:%M UTC')"

pct() {
  local num="${1:-0}"
  local den="${2:-0}"
  awk -v n="$num" -v d="$den" 'BEGIN { if (d<=0) { print "0.0%" } else { printf "%.1f%%", (100*n/d) } }'
}

# Site analytics
SITE_OK=false
TOTAL_PAGEVIEWS=0
TOTAL_APPSTORE_CLICKS=0
CLEAN_PAGEVIEWS=0
CLEAN_APPSTORE_CLICKS=0
TEST_PAGEVIEWS=0
TEST_APPSTORE_CLICKS=0
SITE_PAGEVIEWS_TODAY=0
SITE_APPSTORE_CLICKS_TODAY=0
SITE_PAGEVIEWS_YDAY=0
SITE_APPSTORE_CLICKS_YDAY=0
TOP_PAGES="n/a"
TOP_CLICK_PAGES="n/a"

if [ -x "$WS/scripts/site-analytics-status.sh" ]; then
  bash "$WS/scripts/site-analytics-status.sh" >/dev/null 2>&1 || true
fi

if [ -f "$WS/data/status/site-analytics.json" ] && jq -e '.ok == true' "$WS/data/status/site-analytics.json" >/dev/null 2>&1; then
  SITE_OK=true
  TOTAL_PAGEVIEWS=$(jq -r '.pageviews_total // 0' "$WS/data/status/site-analytics.json")
  TOTAL_APPSTORE_CLICKS=$(jq -r '.app_store_clicks_total // 0' "$WS/data/status/site-analytics.json")
  SITE_PAGEVIEWS_TODAY=$(jq -r '.today_pageviews // 0' "$WS/data/status/site-analytics.json")
  SITE_APPSTORE_CLICKS_TODAY=$(jq -r '.today_app_store_clicks // 0' "$WS/data/status/site-analytics.json")
  SITE_PAGEVIEWS_YDAY=$(jq -r '.yesterday_pageviews // 0' "$WS/data/status/site-analytics.json")
  SITE_APPSTORE_CLICKS_YDAY=$(jq -r '.yesterday_app_store_clicks // 0' "$WS/data/status/site-analytics.json")
  TEST_PAGEVIEWS=$(jq -r '[.top_pageviews[]? | select((.page // "") | test("health-test|test"; "i")) | (.count // 0)] | add // 0' "$WS/data/status/site-analytics.json")
  TEST_APPSTORE_CLICKS=$(jq -r '[.top_click_pages[]? | select((.page // "") | test("health-test|test"; "i")) | (.count // 0)] | add // 0' "$WS/data/status/site-analytics.json")
  CLEAN_PAGEVIEWS=$(( TOTAL_PAGEVIEWS - TEST_PAGEVIEWS ))
  CLEAN_APPSTORE_CLICKS=$(( TOTAL_APPSTORE_CLICKS - TEST_APPSTORE_CLICKS ))
  if [ "$CLEAN_PAGEVIEWS" -lt 0 ]; then CLEAN_PAGEVIEWS=0; fi
  if [ "$CLEAN_APPSTORE_CLICKS" -lt 0 ]; then CLEAN_APPSTORE_CLICKS=0; fi
  TOP_PAGES=$(jq -r '[.top_pageviews[]? | (.page // "?") + " (" + ((.count // 0)|tostring) + ")"] | .[0:3] | join(", ") | if .=="" then "n/a" else . end' "$WS/data/status/site-analytics.json")
  TOP_CLICK_PAGES=$(jq -r '[.top_click_pages[]? | (.page // "?") + " (" + ((.count // 0)|tostring) + ")"] | .[0:3] | join(", ") | if .=="" then "n/a" else . end' "$WS/data/status/site-analytics.json")
fi

CTR_TOTAL=$(pct "$TOTAL_APPSTORE_CLICKS" "$TOTAL_PAGEVIEWS")
CTR_CLEAN=$(pct "$CLEAN_APPSTORE_CLICKS" "$CLEAN_PAGEVIEWS")
CTR_TODAY=$(pct "$SITE_APPSTORE_CLICKS_TODAY" "$SITE_PAGEVIEWS_TODAY")
CTR_YDAY=$(pct "$SITE_APPSTORE_CLICKS_YDAY" "$SITE_PAGEVIEWS_YDAY")

# App Store units/revenue snapshot
APP_REPORT=$(python3 "$WS/scripts/appstore-sales.py" 2>/dev/null || true)
APP_UNITS=$(echo "$APP_REPORT" | awk -F': ' '/Units:/ {print $2; exit}' | tr -d '\r')
APP_REVENUE=$(echo "$APP_REPORT" | awk -F': ' '/Revenue:/ {print $2; exit}' | tr -d '\r')
APP_DATE=$(echo "$APP_REPORT" | sed -n 's/^  Report date (PT): //p' | head -n1 | tr -d '\r')
APP_UNITS=${APP_UNITS:-unknown}
APP_REVENUE=${APP_REVENUE:-unknown}
APP_DATE=${APP_DATE:-unknown}

cat > "$OUT" <<EOF
# KPI DASHBOARD — $(date -u +%Y-%m-%d)

_Generated: ${NOW}_

## 🎯 North Star (Paid Installs)

- App Store report date (PT): ${APP_DATE}
- Units: ${APP_UNITS}
- Revenue: ${APP_REVENUE}

## 🔁 Funnel Health (Site → App Store Click)

| KPI | Value |
|-----|-------|
| Total pageviews | ${TOTAL_PAGEVIEWS} |
| Total App Store clicks | ${TOTAL_APPSTORE_CLICKS} |
| Total click-through rate | ${CTR_TOTAL} |
| Clean pageviews / clicks (excludes test pages) | ${CLEAN_PAGEVIEWS} / ${CLEAN_APPSTORE_CLICKS} |
| Clean click-through rate | ${CTR_CLEAN} |
| Today pageviews / clicks | ${SITE_PAGEVIEWS_TODAY} / ${SITE_APPSTORE_CLICKS_TODAY} |
| Today click-through rate | ${CTR_TODAY} |
| Yesterday pageviews / clicks | ${SITE_PAGEVIEWS_YDAY} / ${SITE_APPSTORE_CLICKS_YDAY} |
| Yesterday click-through rate | ${CTR_YDAY} |

## 🔍 Traffic & Click Concentration

- Top pages (views): ${TOP_PAGES}
- Top pages (App Store clicks): ${TOP_CLICK_PAGES}

## ⚡ Immediate Focus

1. Raise site→App Store CTR on top-viewed pages.
2. Keep instrumentation trustworthy (no missing-secret blind spots).
3. Prioritize work that can move paid installs inside 72 hours.
EOF

echo "kpi:ok:$OUT"