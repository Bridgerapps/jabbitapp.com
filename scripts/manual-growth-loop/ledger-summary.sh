#!/usr/bin/env bash
set -euo pipefail

LEDGER="${1:-/home/jabbit/.openclaw/workspace/data/status/manual-growth-loop-ledger.json}"

if [ ! -f "$LEDGER" ]; then
  echo "ledger not found: $LEDGER" >&2
  exit 1
fi

now=$(date -u +%FT%TZ)

# Fingerprint to detect "no-change" churn across runs.
fingerprint=$(jq -c '
  .sendQueues
  | sort_by(.leadId, .whenUtc, .status, .channel, .to, (.subject // ""))
' "$LEDGER" | sha256sum | awk '{print $1}')

echo "# manual-growth-loop ledger summary"
echo "now: $now"
echo "fingerprint: $fingerprint"

echo

echo "## sendQueues by status"
jq -r '
  .sendQueues
  | group_by(.status)
  | map({status: .[0].status, count: length})
  | sort_by(.status)
  | .[]
  | "- \(.status): \(.count)"
' "$LEDGER"

echo

echo "## ready_to_send (sorted by whenUtc)"
jq -r '
  .sendQueues
  | map(select(.status=="ready_to_send"))
  | sort_by(.whenUtc)
  | (if length==0 then ["- (none)"] else
      map("- \(.whenUtc) | \(.channel) | \(.to) | lead=\(.leadId) | \(.subject // "(no subject)")")
    end)
  | .[]
' "$LEDGER"

echo

echo "## draft_needed (top 5)"
jq -r '
  .sendQueues
  | map(select(.status=="draft_needed"))
  | sort_by(.whenUtc)
  | .[0:5]
  | (if length==0 then ["- (none)"] else
      map("- \(.whenUtc) | \(.channel) | \(.to) | lead=\(.leadId) | \(.subject // "(no subject)")")
    end)
  | .[]
' "$LEDGER"
