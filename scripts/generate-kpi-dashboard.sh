#!/usr/bin/env bash
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
OUT="$WS/docs/kpi-$(date -u +%Y-%m-%d).md"
NOW="$(date -u '+%Y-%m-%d %H:%M UTC')"

COMMITS=$(git -C "$WS" rev-list --count --since='24 hours ago' HEAD 2>/dev/null || echo 0)
FILES=$(git -C "$WS" log --since='24 hours ago' --name-only --pretty=format: 2>/dev/null | sed '/^$/d' | sort -u | wc -l | tr -d ' ')
LINES=$(git -C "$WS" log --since='24 hours ago' --numstat --pretty=format: 2>/dev/null | awk 'NF==3 {a+=$1; d+=$2} END {printf("+%d / -%d", a+0, d+0)}')
GLP=$(find "$WS/jabbitapp.com" -maxdepth 1 -type f -name 'glp1-*.html' 2>/dev/null | wc -l | tr -d ' ')
SITEMAP=$(bash "$WS/scripts/seo-count.sh" 2>/dev/null | tr -d ' ' || echo 0)

# Site analytics (local)
SITE_PAGEVIEWS_TODAY="n/a"
SITE_APPSTORE_CLICKS_TODAY="n/a"
SITE_PAGEVIEWS_YDAY="n/a"
SITE_APPSTORE_CLICKS_YDAY="n/a"
if [ -x "$WS/scripts/site-analytics-status.sh" ]; then
  bash "$WS/scripts/site-analytics-status.sh" >/dev/null 2>&1 || true
fi
if [ -f "$WS/data/status/site-analytics.json" ] && jq -e '.ok == true' "$WS/data/status/site-analytics.json" >/dev/null 2>&1; then
  SITE_PAGEVIEWS_TODAY=$(jq -r '.today_pageviews // 0' "$WS/data/status/site-analytics.json")
  SITE_APPSTORE_CLICKS_TODAY=$(jq -r '.today_app_store_clicks // 0' "$WS/data/status/site-analytics.json")
  SITE_PAGEVIEWS_YDAY=$(jq -r '.yesterday_pageviews // 0' "$WS/data/status/site-analytics.json")
  SITE_APPSTORE_CLICKS_YDAY=$(jq -r '.yesterday_app_store_clicks // 0' "$WS/data/status/site-analytics.json")
fi

cat > "$OUT" <<EOF
# KPI DASHBOARD — $(date -u +%Y-%m-%d)

_Generated: ${NOW}_

## 📈 Proactive Throughput (24h)

| KPI | Value |
|-----|-------|
| Commits (24h) | $COMMITS |
| Files changed (24h) | $FILES |
| Lines added / removed (24h) | $LINES |
| GLP-1 pages live | $GLP |
| Sitemap URLs | $SITEMAP |
| Site visits today / yesterday | $SITE_PAGEVIEWS_TODAY / $SITE_PAGEVIEWS_YDAY |
| App Store clicks today / yesterday | $SITE_APPSTORE_CLICKS_TODAY / $SITE_APPSTORE_CLICKS_YDAY |

## 🎯 Focus
- Ship growth output with measurable distribution impact
- Harden automation and reduce hallucinated/placeholder reporting
- Include explicit data asks in each operator update
EOF

echo "kpi:ok:$OUT"
