#!/usr/bin/env bash
set -euo pipefail

LEDGER="${LEDGER:-/home/jabbit/.openclaw/workspace/data/status/manual-growth-loop-ledger.json}"

usage() {
  cat <<'EOF'
Usage:
  mark-sendqueue-sent.sh <sendQueueId> [--yes]

Safely marks a sendQueue item as sent in manual-growth-loop-ledger.json.
- Without --yes: prints the updated JSON to stdout (no file changes)
- With --yes: writes changes back to the ledger file (in-place)

Examples:
  scripts/manual-growth-loop/mark-sendqueue-sent.sh send-2026-03-08-onthepen-1 > /tmp/ledger.new.json
  scripts/manual-growth-loop/mark-sendqueue-sent.sh send-2026-03-08-onthepen-1 --yes
EOF
}

if [ "${1:-}" = "" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 1
fi

ID="$1"
YES="${2:-}"
NOW_UTC=$(date -u +%FT%TZ)

if [ ! -f "$LEDGER" ]; then
  echo "Ledger not found: $LEDGER" >&2
  exit 2
fi

# Basic validation: ensure id exists.
if ! jq -e --arg id "$ID" '.sendQueues[]? | select(.id==$id) | .id' "$LEDGER" >/dev/null; then
  echo "sendQueue id not found: $ID" >&2
  exit 3
fi

UPDATED_JSON=$(jq --arg id "$ID" --arg now "$NOW_UTC" '
  .lastUpdatedUtc = $now
  | .sendQueues = (
      .sendQueues
      | map(
          if .id == $id then
            .status = "sent"
            | .sentUtc = $now
          else . end
        )
    )
' "$LEDGER")

if [ "$YES" = "--yes" ]; then
  tmp="${LEDGER}.tmp"
  printf "%s\n" "$UPDATED_JSON" > "$tmp"
  mv "$tmp" "$LEDGER"
  echo "OK: marked sent ($ID) @ $NOW_UTC"
else
  printf "%s\n" "$UPDATED_JSON"
fi
