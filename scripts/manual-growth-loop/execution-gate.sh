#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/jabbit/.openclaw/workspace"
LEDGER="${1:-$ROOT/data/status/manual-growth-loop-ledger.json}"
BRIEF_LINK="$ROOT/docs/distribution/send-now-brief-latest.md"

if [[ ! -f "$LEDGER" ]]; then
  echo "ERROR: ledger not found: $LEDGER" >&2
  exit 1
fi

ready_count=$(jq -r '[.sendQueues[] | select(.status=="ready_to_send")] | length' "$LEDGER")

if [[ "$ready_count" == "0" ]]; then
  echo "ok: no ready_to_send items"
  exit 0
fi

now=$(date -u +%FT%TZ)

echo "STOP: ledger has ready_to_send items (count=$ready_count)"
echo "now: $now"

if [[ -L "$BRIEF_LINK" || -f "$BRIEF_LINK" ]]; then
  echo "send-now brief: $BRIEF_LINK"
else
  echo "send-now brief: (missing) expected at $BRIEF_LINK" >&2
fi

echo

echo "Top ready_to_send (up to 5):"
jq -r '
  def to_epoch: ( .whenUtc | sub("\\.[0-9]+Z$";"Z") | fromdateiso8601 );
  .sendQueues
  | map(select(.status=="ready_to_send") + {whenEpoch: (to_epoch)})
  | sort_by(.whenEpoch)
  | .[0:5]
  | map("- [" + .channel + "] " + .to + " @ " + .whenUtc + " (id=" + .id + ")")
  | if length==0 then ["(none)"] else . end
  | .[]
' "$LEDGER"

echo

# Keep a copy/paste pack up to date for the human doing the send.
if [[ -e "$BRIEF_LINK" ]]; then
  "$ROOT/scripts/manual-growth-loop/ensure-send-now-pack-latest.sh" >/dev/null 2>&1 || true
fi

echo "Rule: do NOT create new leads/copy/briefs until these are sent + marked sent."
echo "send-now pack: $ROOT/docs/send-now-pack-latest.txt"
exit 33
