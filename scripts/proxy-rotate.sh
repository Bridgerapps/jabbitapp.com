#!/bin/bash
# Proxy Rotation Helper
# Tests proxies and rotates to next subnet on failure

WORKSPACE="/home/jabbit/.openclaw/workspace"
PROXY_ENV="$WORKSPACE/scripts/proxy.env"

# Source current proxy config
source "$PROXY_ENV"

# List of subnets to try (in order)
SUBNETS=("US-1" "US-2" "US-3" "US-4" "US-5")

# Extract current subnet from PROXY_USER
CURRENT_SUBNET=$(echo "$PROXY_USER" | grep -oE 'US-[0-9]+' || echo "US-1")
CURRENT_NUM=$(echo "$CURRENT_SUBNET" | grep -oE '[0-9]+')

log() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S)] PROXY_ROTATE: $1"
}

# Find index of current subnet
FOUND=0
for i in "${!SUBNETS[@]}"; do
    if [ "${SUBNETS[$i]}" = "$CURRENT_SUBNET" ]; then
        FOUND=1
        break
    fi
done

if [ $FOUND -eq 0 ]; then
    CURRENT_NUM=0
fi

# Try each subnet starting from current
for i in $(seq 0 4); do
    TRY_NUM=$(( (CURRENT_NUM + i) % 5 + 1 ))
    TRY_SUBNET="US-${TRY_NUM}"
    TRY_USER="jxrtqjko-${TRY_SUBNET}"
    TRY_PROXY_URL="http://${TRY_USER}:${PROXY_PASS}@${PROXY_HOST}:${PROXY_PORT}"
    
    log "Testing proxy: $TRY_SUBNET"
    
    # Test connection (quick HEAD request)
    if curl -s -o /dev/null -w '%{http_code}' -x "$TRY_PROXY_URL" \
        --max-time 10 "https://www.reddit.com/api/v1/healthcheck.json" 2>/dev/null | grep -qE "200|401|403"; then
        log "SUCCESS: $TRY_SUBNET works!"
        
        # If not current, update env
        if [ "$TRY_SUBNET" != "$CURRENT_SUBNET" ]; then
            log "Rotating from $CURRENT_SUBNET to $TRY_SUBNET"
            sed -i "s|PROXY_USER=\"jxrtqjko-.*\"|PROXY_USER=\"${TRY_USER}\"|" "$PROXY_ENV"
            
            # Also update jabbitapp.com if exists
            if [ -f "$WORKSPACE/jabbitapp.com/scripts/proxy.env" ]; then
                sed -i "s|PROXY_USER=\"jxrtqjko-.*\"|PROXY_USER=\"${TRY_USER}\"|" "$WORKSPACE/jabbitapp.com/scripts/proxy.env"
            fi
        fi
        
        echo "$TRY_SUBNET"
        exit 0
    else
        log "FAILED: $TRY_SUBNET unavailable"
    fi
done

log "ERROR: All subnets failed!"
echo "NONE"
exit 1
