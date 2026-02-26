#!/bin/bash
# Twitter Health Check & Auto-Recovery Script
# Attempts to reach Twitter via various methods and reports status
# Run: bash scripts/twitter-health-check.sh

echo "=== Twitter Health Check ==="
echo "Time: $(date -Iseconds)"
echo ""

# Check if Late API key is set
if [ -z "$LATE_API_KEY" ]; then
    echo "❌ LATE_API_KEY not set"
    exit 1
fi

echo "✅ LATE_API_KEY is set"
echo ""

# Test 1: Direct Twitter API (Late)
echo "Test 1: Late API (twitter.com)"
RESULT1=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $LATE_API_KEY" "https://api.twitter.com/2/tweets/counts/recent" 2>/dev/null)
if [ "$RESULT1" = "200" ]; then
    echo "✅ Late API: WORKING (HTTP $RESULT1)"
else
    echo "❌ Late API: BLOCKED (HTTP $RESULT1)"
fi

# Test 2: Twitter via alternative endpoint
echo ""
echo "Test 2: Late API (tweets endpoint)"
RESULT2=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $LATE_API_KEY" "https://api.twitter.com/2/users/me" 2>/dev/null)
if [ "$RESULT2" = "200" ]; then
    echo "✅ Users endpoint: WORKING (HTTP $RESULT2)"
else
    echo "❌ Users endpoint: BLOCKED (HTTP $RESULT2)"
fi

# Test 3: Check if it's a JS challenge (returns HTML)
echo ""
echo "Test 3: Check for JS fingerprint challenge"
RESULT3=$(curl -s -w "%{content_type}" -o /dev/null -H "Authorization: Bearer $LATE_API_KEY" "https://api.twitter.com/2/tweets/counts/recent" 2>/dev/null)
if echo "$RESULT3" | grep -q "text/html"; then
    echo "⚠️ JS Challenge detected - returning HTML instead of JSON"
    echo "   This indicates Twitter is blocking automated requests"
else
    echo "✅ No JS challenge detected"
fi

# Test 4: Check TwitterAPI.io as alternative
echo ""
echo "Test 4: TwitterAPI.io (alternative)"
if [ -n "$TWITTERAPI_KEY" ]; then
    RESULT4=$(curl -s -o /dev/null -w "%{http_code}" "https://api.twitterapi.io/twitter/workspace/me" -H "Authorization: Bearer $TWITTERAPI_KEY" 2>/dev/null)
    if [ "$RESULT4" = "200" ]; then
        echo "✅ TwitterAPI.io: WORKING"
    else
        echo "❌ TwitterAPI.io: BLOCKED (HTTP $RESULT4)"
    fi
else
    echo "⚠️ TWITTERAPI_KEY not set - skipping"
fi

# Summary
echo ""
echo "=== Summary ==="
if [ "$RESULT1" = "200" ] || [ "$RESULT2" = "200" ]; then
    echo "✅ Twitter is ACCESSIBLE"
    exit 0
else
    echo "❌ Twitter is BLOCKED"
    echo ""
    echo "Next steps:"
    echo "1. Check docs/twitter-alternatives.md"
    echo "2. Sign up for TwitterAPI.io or alternative"
    echo "3. Or use browser-based posting"
    exit 1
fi
