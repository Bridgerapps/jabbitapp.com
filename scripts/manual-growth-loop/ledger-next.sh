#!/usr/bin/env bash
set -euo pipefail

LEDGER="${1:-/home/jabbit/.openclaw/workspace/data/status/manual-growth-loop-ledger.json}"

if [[ ! -f "$LEDGER" ]]; then
  echo "ERROR: ledger not found: $LEDGER" >&2
  exit 1
fi

now_epoch="$(date -u +%s)"
window_hours="${WINDOW_HOURS:-24}"
window_epoch="$((now_epoch + window_hours*3600))"

# Output: concise next items + overdue ready_to_send
jq -r --argjson now "$now_epoch" --argjson win "$window_epoch" '
  # Some items (e.g. contact_form drafts) may not have whenUtc yet; treat as far-future so they sort last.
  def to_epoch: ( (.whenUtc // "9999-12-31T00:00:00Z") | sub("\\.[0-9]+Z$";"Z") | fromdateiso8601 );

  .sendQueues
  | map(. + {whenEpoch: (to_epoch)})
  | sort_by(.whenEpoch)
  | {
      overdue_ready: map(select(.status=="ready_to_send" and .whenEpoch < $now)
                        | "- [\(.channel)] \(.to) @ \(.whenUtc)  (id=\(.id))"),
      next_24h: map(select(.whenEpoch >= $now and .whenEpoch <= $win)
                   | "- [\(.status)] [\(.channel)] \(.to) @ \(.whenUtc)  (id=\(.id))")
    }
  | "OVERDUE_READY_TO_SEND\n"
    + (if (.overdue_ready|length)==0 then "(none)" else (.overdue_ready | join("\n")) end)
    + "\n\nNEXT_" + ($win - $now | tostring) + "_SECONDS\n"
    + (if (.next_24h|length)==0 then "(none)" else (.next_24h | join("\n")) end)
' "$LEDGER"
