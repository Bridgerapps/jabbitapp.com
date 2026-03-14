#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/jabbit/.openclaw/workspace"
WORKLOG="${1:-$ROOT/WORKLOG.md}"
LEDGER="${LEDGER:-$ROOT/data/status/manual-growth-loop-ledger.json}"
HISTORY_JSON="$ROOT/data/status/manual-growth-loop-history.json"
HISTORY_JSONL="$ROOT/data/logs/manual-growth-loop.jsonl"

print_last5() {
  if [ -s "$HISTORY_JSONL" ]; then
    lc=$(wc -l < "$HISTORY_JSONL" | tr -d ' ')
    if [ "${lc:-0}" -ge 5 ]; then
      echo "# Last 5 runs (from JSONL; most recent first)"
      tail -n 5 "$HISTORY_JSONL" | tac
      return 0
    fi
  fi

  if [ -s "$HISTORY_JSON" ]; then
    echo "# Last 5 runs (from history.json; most recent first)"
    HISTORY_JSON="$HISTORY_JSON" node - <<'NODE'
const fs = require('fs');
const p = process.env.HISTORY_JSON;
let arr=[];
try{arr=JSON.parse(fs.readFileSync(p,'utf8'));}catch{}
arr = Array.isArray(arr) ? arr : [];
const last = arr.slice(Math.max(0, arr.length-5)).reverse();
for (const e of last) console.log(JSON.stringify(e));
NODE
    return 0
  fi

  if [ -f "$WORKLOG" ]; then
    echo "# Last 5 growth-loop lines (from WORKLOG; most recent first)"
    grep -E '— (Growth loop|Self-improvement loop):' "$WORKLOG" | tail -n 5 | tac
    return 0
  fi

  echo "# Last 5 runs: none (no JSONL/history and WORKLOG missing)" >&2
}

LAST5=$(print_last5)
echo "$LAST5"

echo

echo "# Quick repetition hints (keyword frequency in last 5)"
for k in "copy" "outreach" "podcast" "Reddit" "KPI" "measurement" "analytics" "lead" "brief" "ready_to_send" "UTM" "send"; do
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
