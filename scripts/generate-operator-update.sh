#!/usr/bin/env bash
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
SITE_DIR="$WS/jabbitapp.com"
NOW_UTC="$(date -u '+%Y-%m-%d %H:%M UTC')"

# Throughput
COMMITS_24H=$(git -C "$WS" rev-list --count --since='24 hours ago' HEAD 2>/dev/null || echo 0)
UNIQ_FILES_24H=$(git -C "$WS" log --since='24 hours ago' --name-only --pretty=format: 2>/dev/null | sed '/^$/d' | sort -u | wc -l | tr -d ' ')
LINE_STATS=$(git -C "$WS" log --since='24 hours ago' --numstat --pretty=format: 2>/dev/null | awk 'NF==3 {a+=$1; d+=$2} END {printf("+%d/-%d", a+0, d+0)}')

# Recent self-improvement commits
RECENT_FIXES=$(git -C "$WS" log --since='24 hours ago' --pretty=format:'%s' 2>/dev/null | \
  grep -Ei 'fix|improv|guardrail|policy|suppress|cleanup|health|reliab|autonom|cron|memory' | head -n 4 || true)

# Awareness / content
GLP_PAGES=0
LATEST_PAGES=""
SITEMAP_URLS=0
if [ -d "$SITE_DIR" ]; then
  GLP_PAGES=$(find "$SITE_DIR" -maxdepth 1 -type f -name 'glp1-*.html' | wc -l | tr -d ' ')
  LATEST_PAGES=$(find "$SITE_DIR" -maxdepth 1 -type f -name 'glp1-*.html' -printf '%T@ %f\n' | sort -nr | head -n 3 | awk '{print $2}')
  if [ -f "$SITE_DIR/sitemap.xml" ]; then
    SITEMAP_URLS=$(grep -c '<loc>' "$SITE_DIR/sitemap.xml" || true)
  fi
fi

# Pipeline quick status
HEALTH_OUT=$(bash "$WS/scripts/pipeline-health-check.sh" 2>/dev/null || true)
SITE_OK=$(echo "$HEALTH_OUT" | grep -q 'jabbitapp.com (200)' && echo 'ok' || echo 'check')
TWITTER_OK=$(echo "$HEALTH_OUT" | grep -q 'Twitter:' && echo "$HEALTH_OUT" | grep -q '❌' && echo 'blocked' || echo 'ok')

# Needs-from-Jon detection
ASKS=()
[ -f "$WS/data/health/latest_metrics.json" ] || ASKS+=("Share latest health snapshot (sleep avg, resting HR, weight trend, BP, glucose).")
[ -f "$WS/data/health/latest_labs.md" ] || ASKS+=("Drop latest labs/biomarker panel (or photos) so I can update the longevity tracker.")
[ -f "$WS/data/health/protocol-current.md" ] || ASKS+=("Confirm current protocol changes this week (doses, compounds, cadence, side effects).")
[ -n "${APPSTORE_KEY_ID:-}" ] || ASKS+=("Provide App Store Connect read-only API creds so daily download/review metrics are real, not placeholders.")
[ -n "${STRIPE_API_KEY:-}" ] || ASKS+=("Provide Stripe read-only key so revenue/LTV reporting is automated.")

printf "# Operator Update — %s\n\n" "$NOW_UTC"
printf "## What I learned / self-improved\n"
printf -- "- 24h throughput: %s commits, %s files touched, %s lines.\n" "$COMMITS_24H" "$UNIQ_FILES_24H" "$LINE_STATS"
if [ -n "$RECENT_FIXES" ]; then
  echo "$RECENT_FIXES" | sed 's/^/- /'
else
  echo "- No major guardrail commits detected in the last 24h."
fi

echo
printf "## Awareness progress (Jabbit attention)\n"
printf -- "- GLP-1 content footprint: %s pages live; sitemap has %s URLs.\n" "$GLP_PAGES" "$SITEMAP_URLS"
if [ -n "$LATEST_PAGES" ]; then
  echo "$LATEST_PAGES" | sed 's/^/- Shipped: /'
fi

echo
printf "## Life extension play progress\n"
printf -- "- Site health: %s | Twitter distribution lane: %s\n" "$SITE_OK" "$TWITTER_OK"
printf -- "- Current system still over-indexes on publishing. I am now forcing explicit data asks in every operator update until telemetry is connected.\n"

echo
printf "## Asks from you (required to optimize lifespan instead of guessing)\n"
if [ ${#ASKS[@]} -eq 0 ]; then
  echo "- No blocking asks right now."
else
  for a in "${ASKS[@]}"; do
    echo "- $a"
  done
fi

echo
printf "## Next push\n"
printf -- "- I will keep shipping growth + reliability every cycle, and include measurable deltas + asks in each periodic update.\n"
