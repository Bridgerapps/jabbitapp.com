#!/usr/bin/env bash
set -euo pipefail

# Generates a single "send-only" escalation brief when the ready_to_send queue is stuck.
# Goal: stop endless brief churn and force a concrete state change (manual sends + mark sent).

ROOT="/home/jabbit/.openclaw/workspace"
LEDGER="${1:-$ROOT/data/status/manual-growth-loop-ledger.json}"
DIR="$ROOT/docs/distribution"

need() { [ -f "$1" ] || { echo "missing: $1" >&2; exit 1; }; }
need "$LEDGER"

mkdir -p "$DIR"

now_utc=$(date -u +%FT%TZ)
date_utc=$(date -u +%F)
ts_utc=$(date -u +%Y-%m-%d-%H%MZ)

# How stale is the oldest ready_to_send item?
stale_json=$(jq -r '
  [ .sendQueues[] | select(.status=="ready_to_send") | .whenUtc ]
  | sort
  | .[0] // ""
' "$LEDGER")

if [ -z "$stale_json" ]; then
  echo "No ready_to_send items; nothing to escalate."
  exit 0
fi

oldest_when="$stale_json"
oldest_epoch=$(python3 - <<PY
import datetime
s='$oldest_when'
# Accept both Z and +00:00 styles.
if s.endswith('Z'): s=s[:-1]+'+00:00'
print(int(datetime.datetime.fromisoformat(s).timestamp()))
PY
)
now_epoch=$(date -u +%s)
oldest_age_sec=$((now_epoch-oldest_epoch))

THRESHOLD_SEC="${THRESHOLD_SEC:-259200}" # default: 72h

if [ "$oldest_age_sec" -lt "$THRESHOLD_SEC" ]; then
  echo "Oldest ready_to_send age ${oldest_age_sec}s < threshold ${THRESHOLD_SEC}s; skip escalation."
  exit 0
fi

OUT="$DIR/stale-ready-escalation-${ts_utc}.md"
LINK="$DIR/stale-ready-escalation-latest.md"

send_pack="$ROOT/docs/send-now-pack-latest.txt"
brief_link="$ROOT/docs/send-now-brief-latest.md"

{
  echo "# Stale ready_to_send escalation — ${date_utc}"
  echo
  echo "Generated: ${now_utc}"
  echo
  echo "## Situation"
  echo "- ready_to_send has been stuck; oldest item: ${oldest_when} (~${oldest_age_sec}s old)"
  echo "- This loop is now in *send-only* mode until these are advanced (sent/closed)."
  echo
  echo "## What to do (10 minutes)"
  echo "1) Send the top 3 (use the pack for copy/paste)"
  echo "   - pack: ${send_pack}"
  echo "   - brief: ${brief_link}"
  echo "2) Immediately mark them sent in the ledger (commands below)."
  echo
  echo "## ready_to_send (current)"
  jq -r '
    .sendQueues
    | map(select(.status=="ready_to_send"))
    | sort_by(.whenUtc)
    | (if length==0 then ["- (none)"] else
        map(. as $q | ($q.subject // "(no subject)") as $subj | "- id=\($q.id) | when=\($q.whenUtc) | \($q.channel) -> \($q.to) | subject=\($subj)")
      end)
    | .[]
  ' "$LEDGER"
  echo
  echo "## mark-sent commands (run after you send)"
  jq -r '
    .sendQueues
    | map(select(.status=="ready_to_send"))
    | sort_by(.whenUtc)
    | (if length==0 then ["# (none)"] else
        map("scripts/manual-growth-loop/mark-sendqueue-sent.sh \(.id) --yes")
      end)
    | .[]
  ' "$LEDGER"
} > "$OUT"

ln -sf "$(basename "$OUT")" "$LINK"

echo "WROTE: $OUT"
echo "LINK:  $LINK -> $(readlink "$LINK")"
