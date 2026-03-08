#!/usr/bin/env bash
set -euo pipefail

WORKLOG="${1:-/home/jabbit/.openclaw/workspace/WORKLOG.md}"

if [ ! -f "$WORKLOG" ]; then
  echo "WORKLOG not found: $WORKLOG" >&2
  exit 1
fi

echo "# Last 5 growth-loop lines (most recent first)"
# Grab the most recent 5 bullet lines that mention 'Growth loop' or 'Self-improvement loop'
grep -E '— (Growth loop|Self-improvement loop):' "$WORKLOG" | tail -n 5 | tac

echo

echo "# Quick repetition hints (keyword frequency in last 5)"
LAST5=$(grep -E '— (Growth loop|Self-improvement loop):' "$WORKLOG" | tail -n 5)
for k in "copy" "outreach" "podcast" "Reddit" "KPI" "measurement" "analytics" "lead"; do
  c=$(printf "%s\n" "$LAST5" | grep -i -c "$k" || true)
  if [ "$c" -gt 0 ]; then
    printf -- "- %s: %s\n" "$k" "$c"
  fi
done
