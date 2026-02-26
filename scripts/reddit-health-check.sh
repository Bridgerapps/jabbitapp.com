#!/bin/bash
# Reddit API Health Monitor
# Checks Reddit API availability without running full engagement pipeline
# Used to detect when rate limits clear or API becomes accessible

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../data/reddit"
SESSION_FILE="$SCRIPT_DIR/../.reddit-session"

# Create log directory
mkdir -p "$LOG_DIR"

# Load session cookie if available
COOKIE=""
if [ -f "$SESSION_FILE" ]; then
    COOKIE=$(cat "$SESSION_FILE")
fi

# Test subreddits (lightweight check)
TEST_SUBS=("Mounjaro" "Ozempic" "weightloss")
RESULTS=()
STATUS="OK"

for sub in "${TEST_SUBS[@]}"; do
    RESPONSE=$(curl -s -w "\n%{http_code}" -H "User-Agent: Mozilla/5.0" \
        "https://www.reddit.com/r/$sub/new.json?limit=1" 2>/dev/null)
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    
    if [ "$HTTP_CODE" = "200" ]; then
        RESULTS+=("$sub:200")
    elif [ "$HTTP_CODE" = "429" ]; then
        RESULTS+=("$sub:429(RateLimited)")
        STATUS="RATE_LIMITED"
    elif [ "$HTTP_CODE" = "302" ]; then
        RESULTS+=("$sub:302(Redirect)")
        STATUS="REDIRECT"
    else
        RESULTS+=("$sub:$HTTP_CODE")
        if [ "$STATUS" = "OK" ]; then
            STATUS="DEGRADED"
        fi
    fi
done

# Write status file
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "$LOG_DIR/reddit-health.json" << EOF
{
  "timestamp": "$TIMESTAMP",
  "status": "$STATUS",
  "checks": [$(printf '"%s", ' "${RESULTS[@]}" | sed 's/, $//')]
}
EOF

# Output result
echo "=== Reddit Health Check ==="
echo "Status: $STATUS"
printf "Checks: %s\n" "${RESULTS[@]}"
echo "Log: $LOG_DIR/reddit-health.json"
