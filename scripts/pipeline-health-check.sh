#!/bin/bash
# Unified Pipeline Health Check
# Runs in seconds, provides quick status of all components

WORKSPACE="/home/jabbit/.openclaw/workspace"
REDIS_DIR="${WORKSPACE}/data/reddit"
TODAY=$(date +%Y-%m-%d)

echo "=== Pipeline Health Check ==="
echo "Date: $TODAY"
echo ""

# Site Health
echo "🌐 Site:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://www.jabbitapp.com/ 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    echo "  ✅ jabbitapp.com ($HTTP_CODE)"
else
    echo "  ❌ jabbitapp.com ($HTTP_CODE)"
fi

# GitHub Sync
echo ""
echo "📦 GitHub:"
cd "$WORKSPACE" 2>/dev/null
if git rev-parse --git-dir > /dev/null 2>&1; then
    echo "  ✅ Git repo initialized"
    # Check if last commit (proxy for "last push") was today
    # (git log --format expects placeholders like %cd, not strftime tokens)
    LAST_PUSH=$(git log -1 --date=format:%Y-%m-%d --format=%cd 2>/dev/null | head -1)
    if [ "$LAST_PUSH" = "$TODAY" ]; then
        echo "  ✅ Pushed today"
    else
        echo "  ⚠️  Last push: $LAST_PUSH"
    fi
else
    echo "  ❌ Git not initialized"
fi

# Circuit Breaker
echo ""
echo "🔄 Circuit Breaker:"
if [ -f "${REDIS_DIR}/.circuit_breaker" ]; then
    # Try JSON format first, then plain text
    CB_DATE=$(grep -o '"date": "[^"]*"' "${REDIS_DIR}/.circuit_breaker" | cut -d'"' -f4)
    if [ -z "$CB_DATE" ]; then
        CB_DATE=$(cat "${REDIS_DIR}/.circuit_breaker" 2>/dev/null | tr -d '[:space:]')
    fi
    if [ "$CB_DATE" = "$TODAY" ]; then
        echo "  ✅ Reset today"
    else
        echo "  ⚠️  Stale: $CB_DATE"
    fi
else
    echo "  ❌ Missing"
fi

# Data Directory
echo ""
echo "💾 Data:"
if [ -d "$REDIS_DIR" ]; then
    SIZE=$(du -sh "$REDIS_DIR" 2>/dev/null | cut -f1)
    echo "  Reddit data: $SIZE"
    
    # Check for stale files (older than 2 days = 2880 minutes)
    STALE=$(find "$REDIS_DIR" -name "*.json" -mmin +2880 2>/dev/null | wc -l)
    if [ "$STALE" -gt 0 ]; then
        echo "  ⚠️  $STALE stale files (>2 days)"
    else
        echo "  ✅ No stale files"
    fi
else
    echo "  ❌ Reddit data missing"
fi

# Email
echo ""
echo "📧 Email:"
if [ -n "$RESEND_API_KEY" ]; then
    echo "  ✅ API key configured"
else
    echo "  ❌ No API key"
fi

# Twitter
echo ""
echo "🐦 Twitter:"
TWITTER_STATE="${WORKSPACE}/data/twitter_post_state.json"
if [ -f "$TWITTER_STATE" ]; then
    LAST_POST=$(grep -o '"last_post_time": [^,]*' "$TWITTER_STATE" | cut -d' ' -f2)
    if [ -n "$LAST_POST" ]; then
        echo "  Last post: $LAST_POST"
    else
        echo "  ⚠️  No successful posts"
    fi
else
    echo "  ❌ No state file"
fi

# Disk & Memory
echo ""
echo "💻 System:"
DISK=$(df -h /home/jabbit | tail -1 | awk '{print $5}' | sed 's/%//')
echo "  Disk: ${DISK}%"

MEM_AVAIL=$(free -m | awk 'NR==2{print $7}')
echo "  Memory available: ${MEM_AVAIL}MB"

echo ""
echo "=== Summary ==="
echo "Run this script anytime to get a quick pipeline status."
