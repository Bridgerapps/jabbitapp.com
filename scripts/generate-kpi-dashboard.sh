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

## 🎯 Focus
- Ship growth output with measurable distribution impact
- Harden automation and reduce hallucinated/placeholder reporting
- Include explicit data asks in each operator update
EOF

echo "kpi:ok:$OUT"
