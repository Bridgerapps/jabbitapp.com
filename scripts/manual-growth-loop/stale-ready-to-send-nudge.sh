#!/usr/bin/env bash
set -euo pipefail

# Purpose: detect "ready_to_send" stagnation and generate a concise nudge payload.
# Safe: no external sends; just prints a suggested message and updates a local state file.

WS="/home/jabbit/.openclaw/workspace"
LEDGER="$WS/data/status/manual-growth-loop-ledger.json"
STATE="$WS/data/status/manual-growth-loop-nudge.json"

THRESHOLD_SECONDS="${THRESHOLD_SECONDS:-14400}" # 4h default
TOP_N="${TOP_N:-3}"

if [[ ! -f "$LEDGER" ]]; then
  echo "ERR: missing ledger: $LEDGER" >&2
  exit 2
fi

now=$(date -u +%s)

ready_count=$(jq '[.sendQueues[]? | select(.status=="ready_to_send")] | length' "$LEDGER")

# Initialize state if missing
if [[ ! -f "$STATE" ]]; then
  printf '{"lastNudgeUtc":0,"lastReadyCount":0}\n' > "$STATE"
fi

last_nudge=$(jq -r '.lastNudgeUtc // 0' "$STATE")
last_ready=$(jq -r '.lastReadyCount // 0' "$STATE")

delta=$(( now - last_nudge ))

# If queue is empty, just reset count (no nudge)
if [[ "$ready_count" -eq 0 ]]; then
  jq --argjson t "$now" --argjson c "$ready_count" '.lastReadyCount=$c | .lastNudgeUtc=$t' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
  echo "OK: no ready_to_send items (state reset)"
  exit 0
fi

# Nudge only if the queue hasn't changed and we've waited long enough
if [[ "$ready_count" -eq "$last_ready" && "$delta" -lt "$THRESHOLD_SECONDS" ]]; then
  echo "OK: ready_to_send unchanged ($ready_count) but within threshold (${delta}s < ${THRESHOLD_SECONDS}s)"
  exit 0
fi

# Build top-N items for the nudge
items=$(jq -r --argjson n "$TOP_N" '
  [.sendQueues[]?
    | select(.status=="ready_to_send")
    | {leadId:(.leadId//""), channel:(.channel//""), to:(.to//""), subject:(.subject//""), brief:(.sendNowBriefPath//""), mark:(.markSentCommand//"")}
  ][0:$n]
  | map(
      "- " + (if .leadId!="" then .leadId else "(unknown lead)" end)
      + (if .channel!="" then " ("+.channel+")" else "" end)
      + (if .to!="" then ": " + .to else "" end)
      + (if .subject!="" then "\n  subject: " + .subject else "" end)
      + (if .brief!="" then "\n  brief: " + .brief else "" end)
      + (if .mark!="" then "\n  mark: " + .mark else "" end)
    )
  | .[]
' "$LEDGER")

cat <<MSG
NUDGE_READY_TO_SEND
You have $ready_count outreach items ready to send. If you can do one 10-minute burst now, do these (top $TOP_N):

$items

After sending, run the mark-sent commands (so the loop can advance state).
MSG

# Update state
jq --argjson t "$now" --argjson c "$ready_count" '.lastReadyCount=$c | .lastNudgeUtc=$t' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
