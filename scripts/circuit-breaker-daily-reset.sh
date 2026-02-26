#!/bin/bash
# Circuit Breaker Daily Reset Script
# Ensures circuit breaker is properly initialized for each new day
# Run this at the start of each day (e.g., in cron before reddit pipeline)

CIRCUIT_BREAKER="/home/jabbit/.openclaw/workspace/data/reddit/.circuit_breaker"
LOG_FILE="/home/jabbit/.openclaw/workspace/logs/circuit-reset.log"

log() {
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $1" | tee -a "$LOG_FILE"
}

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Get current date
TODAY=$(date +%Y-%m-%d)

# Check if circuit breaker file exists
if [[ -f "$CIRCUIT_BREAKER" ]]; then
    LAST_DATE=$(cat "$CIRCUIT_BREAKER" 2>/dev/null | jq -r '.date // ""')
    
    if [[ "$LAST_DATE" != "$TODAY" ]]; then
        log "New day detected ($LAST_DATE → $TODAY), resetting circuit breaker"
        
        # Read existing values
        LAST_FAILURE=$(cat "$CIRCUIT_BREAKER" 2>/dev/null | jq -r '.last_failure // 0')
        
        # Write new state with reset failures
        jq -n \
            --argjson last_failure "$LAST_FAILURE" \
            --argjson failures 0 \
            --arg date "$TODAY" \
            '{"last_failure": $last_failure, "failures_today": $failures, "date": $date}' > "$CIRCUIT_BREAKER.tmp"
        mv "$CIRCUIT_BREAKER.tmp" "$CIRCUIT_BREAKER"
        
        log "Circuit breaker reset complete: failures_today=0, date=$TODAY"
    else
        log "Circuit breaker already up to date (date=$TODAY)"
    fi
else
    log "No circuit breaker file found, creating new one"
    
    # Create new circuit breaker
    NOW=$(date +%s)
    jq -n \
        --argjson last_failure "$NOW" \
        --argjson failures 0 \
        --arg date "$TODAY" \
        '{"last_failure": $last_failure, "failures_today": $failures, "date": $date}' > "$CIRCUIT_BREAKER"
    
    log "Created new circuit breaker with date=$TODAY"
fi

# Verify the result
log "Current circuit breaker state:"
cat "$CIRCUIT_BREAKER" | jq . >> "$LOG_FILE"

exit 0
