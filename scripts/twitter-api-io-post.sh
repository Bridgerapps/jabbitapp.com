#!/bin/bash
# TwitterAPI.io Integration Script
# Alternative to Late.com API when TwitterAPI.io key is provided
# 
# Setup:
#   1. Sign up at https://twitterapi.io/ (free credits available)
#   2. Get your API key
#   3. Set: export TWITTER_API_KEY="your-api-key"
#   4. Test: ./twitter-api-io-post.sh "Your tweet text"

API_KEY="${TWITTER_API_KEY}"
API_BASE="https://api.twitterapi.io"

if [ -z "$API_KEY" ]; then
    echo "ERROR: TWITTER_API_KEY not set"
    echo "Get free credits at https://twitterapi.io/"
    exit 1
fi

POST_TEXT="$1"

if [ -z "$POST_TEXT" ]; then
    echo "Usage: $0 \"Your tweet text\""
    exit 1
fi

# Send tweet via TwitterAPI.io
RESPONSE=$(curl -s -X POST "$API_BASE/api/v1/tweet/create" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"$POST_TEXT\"}")

# Check response
if echo "$RESPONSE" | grep -q '"success":true'; then
    echo "SUCCESS: Tweet posted"
    echo "$RESPONSE" | jq -r '.data.id // .'
    exit 0
else
    echo "ERROR: Failed to post tweet"
    echo "$RESPONSE"
    exit 1
fi
