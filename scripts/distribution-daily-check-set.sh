#!/usr/bin/env bash
set -euo pipefail

# Update data/status/distribution-daily-check.json with an explicit daily truth.
# Optional: mark a sendQueue item as sent in the manual-growth-loop ledger.
#
# Usage:
#   scripts/distribution-daily-check-set.sh execute --channel email --target dave@onthepen.com --leadId pod-onthepen --queueId send-2026-03-08-onthepen-1 --outcome "sent" --notes "..." --mark-ledger-sent
#   scripts/distribution-daily-check-set.sh skip --reason "travel day" --notes "..."

WS="/home/jabbit/.openclaw/workspace"
OUT="$WS/data/status/distribution-daily-check.json"
LEDGER="$WS/data/status/manual-growth-loop-ledger.json"
DATE_UTC=$(date -u +%Y-%m-%d)
NOW_UTC=$(date -u +%FT%TZ)

cmd="${1:-}"
shift || true

channel=""
target=""
leadId=""
queueId=""
action_type=""
why_this_target=""
outcome=""
next_followup_due_utc=""
skip_reason=""
notes=""
mark_ledger_sent=false

while [ $# -gt 0 ]; do
  case "$1" in
    --channel) channel="$2"; shift 2;;
    --target) target="$2"; shift 2;;
    --leadId) leadId="$2"; shift 2;;
    --queueId) queueId="$2"; shift 2;;
    --action_type) action_type="$2"; shift 2;;
    --why|--why_this_target) why_this_target="$2"; shift 2;;
    --outcome) outcome="$2"; shift 2;;
    --next_followup_due_utc) next_followup_due_utc="$2"; shift 2;;
    --reason|--skip_reason) skip_reason="$2"; shift 2;;
    --notes) notes="$2"; shift 2;;
    --mark-ledger-sent) mark_ledger_sent=true; shift;;
    -h|--help) cmd="help"; shift;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

usage() {
  cat <<'EOF'
Set manual distribution daily execution truth.

Commands:
  execute - mark that we executed one outbound distribution action today
  skip    - mark an explicit skip (must include --reason)

Example:
  scripts/distribution-daily-check-set.sh execute --channel email --target dave@onthepen.com \
    --leadId pod-onthepen --queueId send-2026-03-08-onthepen-1 --outcome "sent" --mark-ledger-sent

  scripts/distribution-daily-check-set.sh skip --reason "no time" --notes "blocked by X"
EOF
}

mkdir -p "$WS/data/status"
if [ ! -f "$OUT" ]; then
  printf '{"date":"%s","executed":false,"channel":"","target":"","leadId":"","queueId":"","action_type":"","why_this_target":"","outcome":"","next_followup_due_utc":"","skip_reason":"","notes":""}\n' "$DATE_UTC" > "$OUT"
fi

case "$cmd" in
  execute)
    if [ -z "$channel" ] || [ -z "$target" ]; then
      echo "execute requires --channel and --target" >&2
      exit 2
    fi
    UPDATED=$(jq --arg date "$DATE_UTC" --arg now "$NOW_UTC" \
      --arg channel "$channel" --arg target "$target" --arg leadId "$leadId" --arg queueId "$queueId" \
      --arg atype "${action_type:-execute}" --arg why "$why_this_target" --arg outcome "$outcome" \
      --arg next "$next_followup_due_utc" --arg notes "$notes" '
        .date=$date
        | .executed=true
        | .skip_reason=""
        | .channel=$channel
        | .target=$target
        | .leadId=$leadId
        | .queueId=$queueId
        | .action_type=$atype
        | .why_this_target=$why
        | .outcome=$outcome
        | .next_followup_due_utc=$next
        | .notes=$notes
        | .last_updated_utc=$now
      ' "$OUT")

    if $mark_ledger_sent && [ -n "$queueId" ]; then
      if [ -f "$LEDGER" ]; then
        # Mark as sent (in-place) using the existing safe helper.
        "$WS/scripts/manual-growth-loop/mark-sendqueue-sent.sh" "$queueId" --yes >/dev/null
      else
        echo "WARN: ledger not found, cannot mark sent: $LEDGER" >&2
      fi
    fi
    ;;
  skip)
    if [ -z "$skip_reason" ]; then
      echo "skip requires --reason" >&2
      exit 2
    fi
    UPDATED=$(jq --arg date "$DATE_UTC" --arg now "$NOW_UTC" \
      --arg reason "$skip_reason" --arg notes "$notes" --arg next "$next_followup_due_utc" '
        .date=$date
        | .executed=false
        | .channel=""
        | .target=""
        | .leadId=""
        | .queueId=""
        | .action_type="skip"
        | .why_this_target=""
        | .outcome=""
        | .next_followup_due_utc=$next
        | .skip_reason=$reason
        | .notes=$notes
        | .last_updated_utc=$now
      ' "$OUT")
    ;;
  help|""|--help|-h)
    usage
    exit 0
    ;;
  *)
    echo "unknown command: $cmd" >&2
    usage
    exit 2
    ;;
esac

TMP="$OUT.tmp"
printf "%s\n" "$UPDATED" > "$TMP"
mv "$TMP" "$OUT"

jq -r '"ok date=\(.date) executed=\(.executed) skip_reason=\(.skip_reason|@json) queueId=\(.queueId|@json)"' "$OUT"
