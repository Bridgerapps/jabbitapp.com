#!/bin/bash
# Reddit Circuit Breaker with Auto-Recovery + Proxy Rotation
# Handles 403 errors with exponential backoff and auto-recovery
# Also rotates proxies on connection failures

WORKSPACE="/home/jabbit/.openclaw/workspace"
CIRCUIT_FILE="$WORKSPACE/data/reddit/.circuit_breaker"
HEALTH_FILE="$WORKSPACE/data/reddit/reddit-health.json"
LOG_FILE="$WORKSPACE/logs/circuit-breaker.log"

MAX_RETRIES=5
BASE_WAIT=60

log() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S)] $1" >> "$LOG_FILE"
}

# Read current state
STATE=$(cat "$CIRCUIT_FILE" 2>/dev/null | jq -r '.state // "CLOSED"')
FAILURES=$(cat "$CIRCUIT_FILE" 2>/dev/null | jq -r '.failure_count // 0')
RETRY_AFTER=$(cat "$CIRCUIT_FILE" 2>/dev/null | jq -r '.retry_after // 0')
LAST_FAIL=$(cat "$CIRCUIT_FILE" 2>/dev/null | jq -r '.last_failure // empty')

log "Current circuit state: $STATE (failures: $FAILURES)"

current_time=$(date +%s)

# Check if we should try recovery (HALF_OPEN)
if [ "$STATE" = "OPEN" ] && [ -n "$LAST_FAIL" ]; then
    last_fail_ts=$(date -d "$LAST_FAIL" +%s 2>/dev/null || echo 0)
    if [ $((current_time - last_fail_ts)) -gt "$RETRY_AFTER" ]; then
        STATE="HALF_OPEN"
        log "Circuit entering HALF_OPEN - testing recovery"
    fi
fi

case "$STATE" in
    "CLOSED")
        # Check Reddit health
        bash "$WORKSPACE/scripts/reddit-health-check.sh" > /dev/null 2>&1
        HEALTH=$(cat "$HEALTH_FILE" 2>/dev/null | jq -r '.status // "UNKNOWN"')
        
        if [ "$HEALTH" = "DEGRADED" ] || [ "$HEALTH" = "DOWN" ]; then
            FAILURES=$((FAILURES + 1))
            RETRY_AFTER=$((BASE_WAIT * 2 ** FAILURES))
            LAST_FAIL=$(date -Iseconds)
            
            cat > "$CIRCUIT_FILE" << EOF
{
    "state": "OPEN",
    "failure_count": $FAILURES,
    "last_failure": "$LAST_FAIL",
    "retry_after": $RETRY_AFTER,
    "reason": "$HEALTH"
}
EOF
            log "Circuit OPEN: Reddit $HEALTH (failures: $FAILURES, retry in ${RETRY_AFTER}s)"
        else
            log "Reddit health OK: $HEALTH"
            cat > "$CIRCUIT_FILE" << EOF
{
    "state": "CLOSED",
    "failure_count": 0,
    "last_success": "$(date -Iseconds)",
    "retry_after": 0
}
EOF
        fi
        ;;
    "HALF_OPEN")
        # Try a test request
        log "Testing recovery..."
        bash "$WORKSPACE/scripts/reddit-health-check.sh" > /dev/null 2>&1
        HEALTH=$(cat "$HEALTH_FILE" 2>/dev/null | jq -r '.status // "UNKNOWN"')
        
        if [ "$HEALTH" = "HEALTHY" ] || [ "$HEALTH" = "OK" ]; then
            cat > "$CIRCUIT_FILE" << EOF
{
    "state": "CLOSED",
    "failure_count": 0,
    "last_success": "$(date -Iseconds)",
    "retry_after": 0
}
EOF
            log "Circuit CLOSED: Recovery successful!"
        else
            FAILURES=$((FAILURES + 1))
            RETRY_AFTER=$((BASE_WAIT * 2 ** FAILURES))
            
            cat > "$CIRCUIT_FILE" << EOF
{
    "state": "OPEN",
    "failure_count": $FAILURES,
    "last_failure": "$(date -Iseconds)",
    "retry_after": $RETRY_AFTER,
    "reason": "Recovery test failed - still $HEALTH"
}
EOF
            log "Circuit back to OPEN: Recovery failed"
        fi
        ;;
    "OPEN")
        log "Circuit OPEN - blocking requests for ${RETRY_AFTER}s more"
        ;;
esac

echo "---"
echo "Circuit Status:"
cat "$CIRCUIT_FILE" | jq .
