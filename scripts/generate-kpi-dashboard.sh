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
SITE_SUSPECT=false
SITE_ERROR=""
SITE_SUSPECT_REASONS=""
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

if [ -f "$WS/data/status/site-analytics.json" ]; then
  SITE_ERROR=$(jq -r '.error // ""' "$WS/data/status/site-analytics.json" 2>/dev/null || echo "")
  if jq -e '.ok == true' "$WS/data/status/site-analytics.json" >/dev/null 2>&1; then
    SITE_OK=true
    SITE_SUSPECT=$(jq -r '.suspect // false' "$WS/data/status/site-analytics.json")
    SITE_SUSPECT_REASONS=$(jq -r '(.suspect_reasons // []) | join(", ")' "$WS/data/status/site-analytics.json")

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
fi

CTR_TOTAL=$(pct "$TOTAL_APPSTORE_CLICKS" "$TOTAL_PAGEVIEWS")
CTR_CLEAN=$(pct "$CLEAN_APPSTORE_CLICKS" "$CLEAN_PAGEVIEWS")
CTR_TODAY=$(pct "$SITE_APPSTORE_CLICKS_TODAY" "$SITE_PAGEVIEWS_TODAY")
CTR_YDAY=$(pct "$SITE_APPSTORE_CLICKS_YDAY" "$SITE_PAGEVIEWS_YDAY")

# App Store installs/downloads (best available: Sales Reports "Units")
APPSTORE_OK=false
APPSTORE_SUSPECT=false
APPSTORE_SUSPECT_REASONS=""
APP_UNITS="unknown"
APP_REVENUE="unknown"
APP_DATE="unknown"

if [ -x "$WS/scripts/appstore-sales-status.sh" ]; then
  bash "$WS/scripts/appstore-sales-status.sh" >/dev/null 2>&1 || true
fi

if [ -f "$WS/data/status/appstore-sales.json" ]; then
  if jq -e '.ok == true' "$WS/data/status/appstore-sales.json" >/dev/null 2>&1; then
    APPSTORE_OK=true
    APPSTORE_SUSPECT=$(jq -r '.suspect // false' "$WS/data/status/appstore-sales.json")
    APPSTORE_SUSPECT_REASONS=$(jq -r '(.suspect_reasons // []) | join(", ")' "$WS/data/status/appstore-sales.json")

    APP_UNITS=$(jq -r '.units // "unknown"' "$WS/data/status/appstore-sales.json")
    APP_REVENUE=$(jq -r '.revenue_usd // "unknown"' "$WS/data/status/appstore-sales.json")
    APP_DATE=$(jq -r '.report_date // "unknown"' "$WS/data/status/appstore-sales.json")
  fi
fi

# Daily execution truth (manual lanes)
REDDIT_CHECK="$WS/data/status/reddit-daily-check.json"
DIST_CHECK="$WS/data/status/distribution-daily-check.json"
LEDGER="$WS/data/status/manual-growth-loop-ledger.json"

REDDIT_STATUS=$(if [ -f "$REDDIT_CHECK" ]; then
  jq -r '
    if (.posted == true) then "POSTED"
    elif ((.skip_reason // "") | length) > 0 then "SKIPPED: " + (.skip_reason|tostring)
    else "UNCONFIRMED (must post or explicitly skip)" end
  ' "$REDDIT_CHECK" 2>/dev/null || echo "BROKEN (invalid json)"
else
  echo "MISSING (no daily check file)"
fi)

DIST_STATUS=$(if [ -f "$DIST_CHECK" ]; then
  jq -r '
    if (.executed == true) then "EXECUTED"
    elif ((.skip_reason // "") | length) > 0 then "SKIPPED: " + (.skip_reason|tostring)
    else "UNCONFIRMED (must execute or explicitly skip)" end
  ' "$DIST_CHECK" 2>/dev/null || echo "BROKEN (invalid json)"
else
  echo "MISSING (no daily check file)"
fi)

READY_TO_SEND_COUNT=0
READY_TO_SEND_OLDEST=""
if [ -f "$LEDGER" ]; then
  READY_TO_SEND_COUNT=$(jq -r '[.sendQueues[]? | select(.status=="ready_to_send")] | length' "$LEDGER" 2>/dev/null || echo 0)
  READY_TO_SEND_OLDEST=$(jq -r '[.sendQueues[]? | select(.status=="ready_to_send") | .whenUtc] | sort | .[0] // ""' "$LEDGER" 2>/dev/null || echo "")
fi

cat > "$OUT" <<EOF
# KPI DASHBOARD — $(date -u +%Y-%m-%d)

_Generated: ${NOW}_

## 🎯 North Star (Installs / Downloads)

- **Primary metric:** installs/downloads (best available: App Store Connect Sales Reports → Units).
- App Store sales status: $(if $APPSTORE_OK; then echo "OK"; else echo "BROKEN"; fi)$(if [ "$APPSTORE_SUSPECT" = "true" ]; then echo " — SUSPECT${APPSTORE_SUSPECT_REASONS:+ ($APPSTORE_SUSPECT_REASONS)}"; fi)
- App Store report date (PT): ${APP_DATE}
- **Units (App Units / downloads):** ${APP_UNITS}
- Revenue (secondary): ${APP_REVENUE}

## 🔁 Funnel Health (Site → App Store Click)

- Site analytics status: $(if $SITE_OK; then echo "OK"; else echo "BROKEN${SITE_ERROR:+ ($SITE_ERROR)}"; fi)$(if [ "$SITE_SUSPECT" = "true" ]; then echo " — SUSPECT${SITE_SUSPECT_REASONS:+ ($SITE_SUSPECT_REASONS)}"; fi)

| KPI | Value |
|-----|-------|
| Total pageviews | $(if $SITE_OK; then echo "${TOTAL_PAGEVIEWS}"; else echo "unknown"; fi) |
| Total App Store clicks | $(if $SITE_OK; then echo "${TOTAL_APPSTORE_CLICKS}"; else echo "unknown"; fi) |
| Total click-through rate | $(if $SITE_OK; then echo "${CTR_TOTAL}"; else echo "n/a"; fi) |
| Clean pageviews / clicks (excludes test pages) | $(if $SITE_OK; then echo "${CLEAN_PAGEVIEWS} / ${CLEAN_APPSTORE_CLICKS}"; else echo "unknown"; fi) |
| Clean click-through rate | $(if $SITE_OK; then echo "${CTR_CLEAN}"; else echo "n/a"; fi) |
| Today pageviews / clicks | $(if $SITE_OK; then echo "${SITE_PAGEVIEWS_TODAY} / ${SITE_APPSTORE_CLICKS_TODAY}"; else echo "unknown"; fi) |
| Today click-through rate | $(if $SITE_OK; then echo "${CTR_TODAY}"; else echo "n/a"; fi) |
| Yesterday pageviews / clicks | $(if $SITE_OK; then echo "${SITE_PAGEVIEWS_YDAY} / ${SITE_APPSTORE_CLICKS_YDAY}"; else echo "unknown"; fi) |
| Yesterday click-through rate | $(if $SITE_OK; then echo "${CTR_YDAY}"; else echo "n/a"; fi) |

## 🔍 Traffic & Click Concentration

- Top pages (views): ${TOP_PAGES}
- Top pages (App Store clicks): ${TOP_CLICK_PAGES}

## ✅ Daily execution truth (manual lanes)

- Reddit today: ${REDDIT_STATUS}
- Manual distribution today: ${DIST_STATUS}
- Ready-to-send backlog: ${READY_TO_SEND_COUNT}$(if [ -n "$READY_TO_SEND_OLDEST" ]; then echo " (oldest whenUtc: $READY_TO_SEND_OLDEST)"; fi)

## ⚡ Immediate Focus

1. Raise site→App Store CTR on top-viewed pages.
2. Keep instrumentation trustworthy (no missing-secret blind spots).
3. Prioritize work that can move installs inside 72 hours (don’t confuse revenue with installs).
EOF

echo "kpi:ok:$OUT"