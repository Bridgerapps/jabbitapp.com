#!/usr/bin/env bash
set -euo pipefail

WORKLOG="${1:-/home/jabbit/.openclaw/workspace/WORKLOG.md}"
LEDGER="${LEDGER:-/home/jabbit/.openclaw/workspace/data/status/manual-growth-loop-ledger.json}"

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
for k in "copy" "outreach" "podcast" "Reddit" "KPI" "measurement" "analytics" "lead" "brief" "ready_to_send"; do
  c=$(printf "%s\n" "$LAST5" | grep -i -c "$k" || true)
  if [ "$c" -gt 0 ]; then
    printf -- "- %s: %s\n" "$k" "$c"
  fi
done

echo

echo "# Queue stagnation check (ledger)"
if [ -f "$LEDGER" ]; then
  now=$(date -u +%s)
  ready=$(jq -r '[.sendQueues[]? | select(.status=="ready_to_send")] | length' "$LEDGER")
  oldest=$(jq -r '
    def to_epoch:
      ( .whenUtc // "" )
      | if .=="" then null
        else (sub("\\.[0-9]+Z$";"Z") | fromdateiso8601)
        end;
    [.sendQueues[]? | select(.status=="ready_to_send") | to_epoch]
    | map(select(.!=null))
    | if length==0 then null else (min) end
  ' "$LEDGER")

  if [ "$oldest" != "null" ]; then
    age=$(( now - oldest ))
    printf -- "- ready_to_send: %s (oldest_age_sec=%s)\n" "$ready" "$age"
    if [ "$age" -ge 14400 ]; then
      echo "- hint: queue is stale; run scripts/manual-growth-loop/stale-ready-to-send-nudge.sh"
    fi
  else
    printf -- "- ready_to_send: %s\n" "$ready"
  fi
else
  echo "- ledger missing (skipped): $LEDGER"
fi
