#!/usr/bin/env bash
set -euo pipefail

# Purpose: detect "ready_to_send" stagnation and generate a concise nudge payload.
# Safe: no external sends; just prints a suggested message and updates a local state file.
#
# Upgrades (2026-03-10):
# - track unchangedNudges (execution-debt counter)
# - include oldest_age_sec to detect true stagnation even if count changes
# - point to docs/send-now-pack-latest.txt when available (copy/paste assist)

WS="/home/jabbit/.openclaw/workspace"
LEDGER="$WS/data/status/manual-growth-loop-ledger.json"
STATE="$WS/data/status/manual-growth-loop-nudge.json"
PACK_LATEST="$WS/docs/send-now-pack-latest.txt"

THRESHOLD_SECONDS="${THRESHOLD_SECONDS:-14400}" # 4h default
TOP_N="${TOP_N:-3}"
ESCALATE_AGE_SECONDS="${ESCALATE_AGE_SECONDS:-86400}" # 24h
ESCALATE_NUDGES="${ESCALATE_NUDGES:-3}"

if [[ ! -f "$LEDGER" ]]; then
  echo "ERR: missing ledger: $LEDGER" >&2
  exit 2
fi

now=$(date -u +%s)

ready_count=$(jq '[.sendQueues[]? | select(.status=="ready_to_send")] | length' "$LEDGER")

# Oldest whenUtc among ready_to_send (may be empty)
oldest_when=$(jq -r '[.sendQueues[]? | select(.status=="ready_to_send") | .whenUtc] | map(select(.!=null)) | sort | .[0] // ""' "$LEDGER")
oldest_age_sec=0
if [[ -n "$oldest_when" ]]; then
  oldest_epoch=$(date -u -d "$oldest_when" +%s 2>/dev/null || echo "")
  if [[ -n "$oldest_epoch" ]]; then
    oldest_age_sec=$(( now - oldest_epoch ))
  fi
fi

# Initialize state if missing
if [[ ! -f "$STATE" ]]; then
  printf '{"lastNudgeUtc":0,"lastReadyCount":0,"unchangedNudges":0}\n' > "$STATE"
fi

last_nudge=$(jq -r '.lastNudgeUtc // 0' "$STATE")
last_ready=$(jq -r '.lastReadyCount // 0' "$STATE")
unchanged_nudges=$(jq -r '.unchangedNudges // 0' "$STATE")

delta=$(( now - last_nudge ))

# If queue is empty, just reset state
if [[ "$ready_count" -eq 0 ]]; then
  jq --argjson t "$now" --argjson c "$ready_count" '.lastReadyCount=$c | .lastNudgeUtc=$t | .unchangedNudges=0' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
  echo "OK: no ready_to_send items (state reset)"
  exit 0
fi

# Nudge only if the queue hasn't changed AND we've waited long enough.
# (If count changed, we allow a nudge immediately because it's new work.)
if [[ "$ready_count" -eq "$last_ready" && "$delta" -lt "$THRESHOLD_SECONDS" ]]; then
  echo "OK: ready_to_send unchanged ($ready_count) but within threshold (${delta}s < ${THRESHOLD_SECONDS}s)"
  exit 0
fi

# Update unchanged nudge counter
if [[ "$ready_count" -eq "$last_ready" ]]; then
  unchanged_nudges=$((unchanged_nudges + 1))
else
  unchanged_nudges=0
fi

# Build top-N items for the nudge
items=$(jq -r --argjson n "$TOP_N" '
  [.sendQueues[]?
    | select(.status=="ready_to_send")
    | {leadId:(.leadId//""), channel:(.channel//""), to:(.to//""), subject:(.subject//""), brief:(.brief//""), doc:(.doc//""), id:(.id//"")}
  ][0:$n]
  | map(
      "- " + (if .leadId!="" then .leadId else "(unknown lead)" end)
      + (if .channel!="" then " ("+.channel+")" else "" end)
      + (if .to!="" then ": " + .to else "" end)
      + (if .subject!="" then "\n  subject: " + .subject else "" end)
      + (if .brief!="" then "\n  brief: " + .brief else "" end)
      + (if .doc!="" then "\n  doc: " + .doc else "" end)
      + (if .id!="" then "\n  id: " + .id else "" end)
    )
  | .[]
' "$LEDGER")

pack_hint=""
if [[ -f "$PACK_LATEST" ]]; then
  pack_hint="\nCopy/paste pack: docs/send-now-pack-latest.txt"
fi

escalation=""
if [[ "$oldest_age_sec" -ge "$ESCALATE_AGE_SECONDS" || "$unchanged_nudges" -ge "$ESCALATE_NUDGES" ]]; then
  escalation="ESCALATION: queue is stale (oldest_age_sec=${oldest_age_sec}, unchangedNudges=${unchanged_nudges}). Either send top-3 now or explicitly deprioritize/close leads so the loop can move."
fi

cat <<MSG
NUDGE_READY_TO_SEND
You have $ready_count outreach items ready to send (oldest_age_sec=$oldest_age_sec). If you can do one 10-minute burst now, do these (top $TOP_N):

$items
$pack_hint

After sending, mark them sent in the ledger (so the loop can advance state).
$escalation
MSG

# Update state
jq --argjson t "$now" --argjson c "$ready_count" --argjson u "$unchanged_nudges" '.lastReadyCount=$c | .lastNudgeUtc=$t | .unchangedNudges=$u' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
