#!/usr/bin/env bash
set -euo pipefail

LEDGER="${1:-/home/jabbit/.openclaw/workspace/data/status/manual-growth-loop-ledger.json}"

if [ ! -f "$LEDGER" ]; then
  echo "Ledger not found: $LEDGER" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

echo "Ready-to-send items:"

jq -r '
  .sendQueues
  | map(select(.status=="ready_to_send"))
  | sort_by(.whenUtc)
  | .[]
  | "- \(.whenUtc) | \(.id) | \(.channel) -> \(.to) | subj: \(.subject // "(none)") | brief: \(.brief // "(none)")"
' "$LEDGER"

COUNT=$(jq '[.sendQueues[] | select(.status=="ready_to_send")] | length' "$LEDGER")

echo

echo "Total: $COUNT"
