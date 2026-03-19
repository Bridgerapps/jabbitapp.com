#!/usr/bin/env bash
set -euo pipefail

LEDGER="${LEDGER:-/home/jabbit/.openclaw/workspace/data/status/manual-growth-loop-ledger.json}"
OUT_DIR="${OUT_DIR:-/home/jabbit/.openclaw/workspace/data/status}"
OUT_FILE="${OUT_FILE:-$OUT_DIR/owner-send-ping-latest.txt}"
LIMIT="${LIMIT:-5}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

if [ ! -f "$LEDGER" ]; then
  echo "Ledger not found: $LEDGER" >&2
  exit 3
fi

mkdir -p "$OUT_DIR"

NOW_UTC=$(date -u +%FT%TZ)
TOP3_FILE="$OUT_DIR/manual-growth-loop-awaiting-owner-top3-latest.json"

# Prefer ready_to_send. If none exist, prefer the curated awaiting_owner top-3 shortlist (if present),
# otherwise fall back to a naive awaiting_owner sort so Jon still has a clear next action.
READY_JSON=$(jq -c --argjson n "$LIMIT" '
  .sendQueues
  | map(select(.status=="ready_to_send"))
  | sort_by(.whenUtc)
  | .[0:$n]
' "$LEDGER")
READY_COUNT=$(jq 'length' <<<"$READY_JSON")

AWAITING_JSON=$(jq -c --argjson n "$LIMIT" '
  .sendQueues
  | map(select(.status=="awaiting_owner"))
  | map(. + {__priority:(
      if (.awaitingOwnerReason=="needs-approval") then 0
      elif (.awaitingOwnerReason=="stale-ready-auto-demote") then 1
      else 2 end
    )})
  | sort_by(.__priority, (.awaitingOwnerUtc // .updatedUtc // "9999-12-31T00:00:00Z"))
  | map(del(.__priority))
  | .[0:$n]
' "$LEDGER")

if [ "$READY_COUNT" -eq 0 ] && [ -f "$TOP3_FILE" ]; then
  # Shape the curated shortlist into the same shape used below.
  AWAITING_JSON=$(jq -c --argjson n "$LIMIT" '.top3 | .[0:$n] | map({id: .sendQueueId, channel, to, subject, brief})' "$TOP3_FILE")
fi

AWAITING_COUNT=$(jq 'length' <<<"$AWAITING_JSON")

{
  echo "MANUAL SEND PING (generated $NOW_UTC)"
  echo
  echo "Context: These are the next outbound touches awaiting your approval/send (nothing is auto-sent)."
  echo
  echo "PRE-FLIGHT (release-blocking):"
  echo "- Verify From name + From email/domain + Reply-To are correct (use jabbit/jabbitapp.com for outreach)"
  echo "- Verify all links go to jabbit/jabbitapp.com (no stray domains)"
  echo "- Prefer a test send to yourself first (canary)"
  echo
  echo "SEND PACKS:"
  echo "- Copy/paste pack: docs/send-now-pack-latest.txt"
  echo "- One-click mailto drafts: docs/send-now-mailto-links-latest.md"
  echo

  if [ "$READY_COUNT" -gt 0 ]; then
    echo "TOP READY_TO_SEND ($READY_COUNT shown):"
    jq -r '.[] | "- id: \(.id)\n  channel: \(.channel)\n  to: \(.to)\n  subject: \(.subject // "(none)")\n  brief: \(.brief // "(none)")\n  mark sent: scripts/manual-growth-loop/mark-sendqueue-sent.sh \(.id) --yes\n"' <<<"$READY_JSON"
  elif [ "$AWAITING_COUNT" -gt 0 ]; then
    echo "NO ready_to_send items. TOP AWAITING_OWNER ($AWAITING_COUNT shown):"
    jq -r '.[] | "- id: \(.id)\n  channel: \(.channel)\n  to: \(.to)\n  subject: \(.subject // "(none)")\n  brief: \(.brief // "(none)")\n  after sending: scripts/manual-growth-loop/mark-sendqueue-sent.sh \(.id) --yes\n"' <<<"$AWAITING_JSON"
  else
    echo "No ready_to_send or awaiting_owner items found."
  fi
} | tee "$OUT_FILE"

echo

echo "WROTE: $OUT_FILE"
