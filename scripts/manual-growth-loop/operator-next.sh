#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/jabbit/.openclaw/workspace"
LEDGER="$ROOT/data/status/manual-growth-loop-ledger.json"

# Purpose: single entrypoint that tells the operator the *one* next move,
# to avoid churn when guardrails intentionally STOP normal execution.

set +e
"$ROOT/scripts/manual-growth-loop/preflight.sh" >/tmp/manual-growth-loop-preflight.txt 2>&1
code=$?
set -e

cat /tmp/manual-growth-loop-preflight.txt

echo "---"

case "$code" in
  0)
    echo "NEXT: run normal growth actions (preflight OK)"
    ;;
  22)
    echo "NEXT: self-improvement run (iteration%5==0) — do NOT do normal tasks first"
    ;;
  33)
    echo "NEXT: SEND-ONLY. Queue is stale — send + mark sent before creating new work."
    echo "hint: $ROOT/scripts/manual-growth-loop/stale-ready-to-send-nudge.sh"
    echo "hint: after sending, mark sent with: $ROOT/scripts/manual-growth-loop/mark-sendqueue-sent.sh <sendQueueId>"

    if [ -f "$LEDGER" ]; then
      echo "---"
      echo "Top ready_to_send (oldest first):"
      jq -r '.sendQueues
        | map(select(.status=="ready_to_send"))
        | sort_by(.whenUtc // "")
        | .[0:5]
        | .[]
        | "- id=\(.id) channel=\(.channel) to=\(.to // "") whenUtc=\(.whenUtc)"' "$LEDGER" 2>/dev/null || true
    fi
    ;;
  *)
    echo "NEXT: investigate preflight failure (exit=$code) — see output above"
    ;;
esac

exit "$code"
