#!/usr/bin/env bash
set -euo pipefail

LEDGER="${LEDGER:-/home/jabbit/.openclaw/workspace/data/status/manual-growth-loop-ledger.json}"
OUT_DIR="${OUT_DIR:-/home/jabbit/.openclaw/workspace/data/status}"
OUT_FILE="${OUT_FILE:-$OUT_DIR/owner-send-ping-latest.txt}"
LIMIT="${LIMIT:-3}"

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

# Prefer ready_to_send. If none exist, fall back to awaiting_owner so Jon still has a clear next action.
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
  | sort_by(.awaitingOwnerUtc // .updatedUtc // "9999-12-31T00:00:00Z")
  | .[0:$n]
' "$LEDGER")
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
