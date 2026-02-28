#!/bin/bash
# Circuit Breaker Daily Reset Script
# Ensures circuit breaker is properly initialized for each new day
# Run this at the start of each day (e.g., in cron before reddit pipeline)

set -euo pipefail

CIRCUIT_BREAKER="/home/jabbit/.openclaw/workspace/data/reddit/.circuit_breaker"
LOG_FILE="/home/jabbit/.openclaw/workspace/logs/circuit-reset.log"

log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $1" | tee -a "$LOG_FILE"
}

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

TODAY="$(date +%Y-%m-%d)"
NOW_EPOCH="$(date +%s)"

if ! command -v jq >/dev/null 2>&1; then
  log "ERROR: jq is required for circuit breaker state";
  exit 2
fi

is_valid_json() {
  local f="$1"
  jq -e . "$f" >/dev/null 2>&1
}

read_field() {
  local query="$1"
  local f="$2"
  jq -r "$query" "$f" 2>/dev/null || true
}

write_state() {
  local last_failure="$1"
  local failures_today="$2"

  # Ensure numeric JSON for last_failure / failures_today
  if ! [[ "$last_failure" =~ ^[0-9]+$ ]]; then
    last_failure="$NOW_EPOCH"
  fi
  if ! [[ "$failures_today" =~ ^[0-9]+$ ]]; then
    failures_today="0"
  fi

  jq -n \
    --arg date "$TODAY" \
    --argjson last_failure "$last_failure" \
    --argjson failures_today "$failures_today" \
    '{last_failure:$last_failure, failures_today:$failures_today, date:$date}'
}

LAST_DATE=""
LAST_FAILURE="$NOW_EPOCH"

if [[ -f "$CIRCUIT_BREAKER" ]] && is_valid_json "$CIRCUIT_BREAKER"; then
  LAST_DATE="$(read_field '.date // ""' "$CIRCUIT_BREAKER" | tr -d '[:space:]')"
  LAST_FAILURE="$(read_field '.last_failure // 0' "$CIRCUIT_BREAKER" | tr -d '[:space:]')"
else
  # If missing or corrupt, we treat it as missing and recreate.
  if [[ -f "$CIRCUIT_BREAKER" ]]; then
    log "WARN: circuit breaker file exists but is not valid JSON; recreating"
  else
    log "No circuit breaker file found; creating new one"
  fi
fi

if [[ "$LAST_DATE" != "$TODAY" ]]; then
  log "New day detected (${LAST_DATE:-none} -> $TODAY), resetting circuit breaker"
  write_state "$LAST_FAILURE" 0 > "${CIRCUIT_BREAKER}.tmp"
  mv "${CIRCUIT_BREAKER}.tmp" "$CIRCUIT_BREAKER"
  log "Circuit breaker reset complete: failures_today=0, date=$TODAY"
else
  log "Circuit breaker already up to date (date=$TODAY)"
fi

log "Current circuit breaker state:"
jq . "$CIRCUIT_BREAKER" >> "$LOG_FILE"

exit 0
