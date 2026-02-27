#!/bin/bash
# SEO Page Topic Checker
# Usage: bash scripts/check-seo-topic.sh "topic-name"
# Returns: 0 if topic exists, 1 if not found

WORKSPACE="/home/jabbit/.openclaw/workspace"
TRACKER="$WORKSPACE/data/seo/page-tracker.json"

if [ -z "$1" ]; then
    echo "Usage: $0 <topic-name>"
    exit 1
fi

TOPIC="$1"

# Check if topic exists in tracker
if [ -f "$TRACKER" ]; then
    RESULT=$(cat "$TRACKER" | jq -r ".topics[] | select(.topic == \"$TOPIC\") | .filename" 2>/dev/null)
    if [ -n "$RESULT" ]; then
        echo "EXISTS: $TOPIC -> $RESULT"
        exit 0
    fi
fi

# Also check filesystem
EXISTING=$(find "$WORKSPACE" -maxdepth 1 -name "*.html" -exec basename {} \; | grep -i "$TOPIC" | head -1)
if [ -n "$EXISTING" ]; then
    echo "EXISTS: $TOPIC -> $EXISTING"
    exit 0
fi

echo "AVAILABLE: $TOPIC can be created"
exit 1
