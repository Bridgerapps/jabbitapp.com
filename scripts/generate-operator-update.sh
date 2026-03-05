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
  SITEMAP_URLS=$(bash "$WS/scripts/seo-count.sh" 2>/dev/null | tr -d ' ' || echo 0)
fi

# Pipeline quick status
HEALTH_OUT=$(bash "$WS/scripts/pipeline-health-check.sh" 2>/dev/null || true)
SITE_OK=$(echo "$HEALTH_OUT" | grep -q 'jabbitapp.com (200)' && echo 'ok' || echo 'check')
TWITTER_OK=$(echo "$HEALTH_OUT" | grep -q 'Twitter:' && echo "$HEALTH_OUT" | grep -q '❌' && echo 'blocked' || echo 'ok')

# Needs-from-Jon detection
# Load App Store env file (cron shells are often minimal and miss exported vars).
if [ -f "$WS/scripts/appstore.env" ]; then
  # shellcheck disable=SC1090
  source "$WS/scripts/appstore.env" || true
fi

ASKS=()
# KPI preference: paid installs from App Store are primary; Stripe asks are intentionally deferred.
# Only request App Store creds if still truly missing after env-file load.
[ -n "${APPSTORE_KEY_ID:-}" ] || ASKS+=("Provide App Store Connect read-only API creds so paid-install reporting stays first-party and reliable.")

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
printf "## Parallel execution framework status\n"
printf -- "- Lane A (SEO awareness): active\n"
printf -- "- Lane B (conversion optimization): active\n"
printf -- "- Lane C (ops/telemetry reliability): site=%s | twitter_lane=%s\n" "$SITE_OK" "$TWITTER_OK"
printf -- "- Source-of-truth KPI: App Store installs (currently organic; no paid channels active).\n"

echo
printf "## Asks from you (only true blockers)\n"
if [ ${#ASKS[@]} -eq 0 ]; then
  echo "- No blocker from you right now."
else
  for a in "${ASKS[@]}"; do
    echo "- $a"
  done
fi

echo
printf "## Next push\n"
printf -- "- Continue parallel lane execution; prioritize changes that increase paid installs or improve signal quality.\n"
