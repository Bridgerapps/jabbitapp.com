#!/usr/bin/env bash
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
DATE="$(date -u +%Y-%m-%d)"
OUT="$WS/docs/self-improvement-$DATE.md"

COMMITS=$(git -C "$WS" log --since='24 hours ago' --pretty=format:'- %h %s' | sed -n '1,20p' || true)

# Ensure latest KPI snapshot exists
bash "$WS/scripts/generate-kpi-dashboard.sh" >/dev/null 2>&1 || true
KPI_FILE="$WS/docs/kpi-$DATE.md"

cat > "$OUT" <<EOF
# SELF-IMPROVEMENT LOG — $DATE

## What mattered for downloads today
- Read KPI first: $KPI_FILE
- Did we increase site→App Store click-through on top-traffic pages?
- Did we increase paid installs (units/revenue), not just output volume?

## Repeated failures captured
- Review REGRESSIONS.md and append any new failure → guardrail lines.
- If a metric looked good due to test traffic, add a guardrail.

## Evidence (last 24h commits)
$COMMITS

## Weekly hard questions (no fluff)
1. Which changes moved paid installs vs looked busy?
2. Which scripts/pages consumed effort with zero measurable lift?
3. What do we stop doing next week?
4. What one experiment has highest expected lift in 72h?

## Deep system check (weekly)
1. Core files present: MEMORY.md, REGRESSIONS.md, WORKFLOW_AUTO.md, USER.md, IDENTITY.md, SOUL.md, AGENTS.md
2. Cron health: `openclaw cron list` and flag failed/stale jobs (>24h)
3. Measurement health: `scripts/site-analytics-status.sh` returns ok=true
4. Revenue health: `python3 scripts/appstore-sales.py` parses cleanly

## Next 24h plan (must be conversion-linked)
1. One instrumentation integrity task
2. One CRO change on highest-traffic page
3. One distribution test with explicit kill criteria
EOF

echo "self-improvement:ok:$OUT"