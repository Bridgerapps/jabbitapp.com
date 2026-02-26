#!/usr/bin/env bash
# Unified Twitter Pipeline Script
# Handles posting, health checks, and recovery

set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
ACTION="${1:-status}"

case "$ACTION" in
    post)
        echo "=== Twitter: Posting via API ==="
        bash "$WS/scripts/twitter-api-io-post.sh"
        ;;
    health|status)
        echo "=== Twitter: Health Check ==="
        
        # Check if Late API key is set
        if [ -n "${LATE_API_KEY:-}" ]; then
            echo "✅ Late API key configured"
        else
            echo "❌ Late API key missing"
        fi
        
        # Check queue status
        if [ -f "$WS/data/twitter_content_queue.json" ]; then
            QLEN=$(python3 -c "import json; print(len(json.load(open('$WS/data/twitter_content_queue.json'))))" 2>/dev/null || echo "0")
            echo "📝 Queue: $QLEN posts pending"
        else
            echo "📝 Queue: not found"
        fi
        
        # Check circuit breaker
        if [ -f "$WS/data/twitter/.circuit_breaker" ]; then
            CB=$(cat "$WS/data/twitter/.circuit_breaker" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"failures:{d.get('failures_today',0)}, date:{d.get('date','')}\")" 2>/dev/null || echo "unknown")
            echo "🔄 Circuit: $CB"
        else
            echo "🔄 Circuit: not initialized"
        fi
        ;;
    reset-circuit)
        echo "=== Twitter: Reset Circuit Breaker ==="
        mkdir -p "$WS/data/twitter"
        TODAY=$(date +%Y-%m-%d)
        echo "{\"last_failure\": 0, \"failures_today\": 0, \"date\": \"$TODAY\"}" > "$WS/data/twitter/.circuit_breaker"
        echo "✅ Circuit breaker reset"
        ;;
    test)
        echo "=== Twitter: Browser Test ==="
        bash "$WS/scripts/twitter-browser-test.sh"
        ;;
    *)
        echo "Usage: $0 {post|health|reset-circuit|test}"
        echo "  post         - Post next tweet from queue"
        echo "  health       - Check Twitter pipeline health"
        echo "  reset-circuit - Reset circuit breaker"
        echo "  test         - Run browser test"
        exit 1
        ;;
esac
