#!/bin/bash
# reddit-post-new-page.sh - Auto-post new SEO pages to Reddit
# Usage: ./reddit-post-new-page.sh <html-file>
# Requires: Reddit API credentials in data/reddit-credentials.env

SOURCE_DIR="/home/jabbit/.openclaw/workspace/jabbitapp.com"
DATA_DIR="/home/jabbit/.openclaw/workspace/data"
LOG_FILE="$DATA_DIR/logs/reddit-posts.log"

# Check if file provided
if [ -z "$1" ]; then
    echo "Usage: $0 <html-file> [subreddit]"
    echo "Example: $0 glp1-cost-without-insurance.html mounjaro"
    exit 1
fi

FILE="$1"
SUBREDDIT="${2:-Mounjaro}"

# Check file exists
if [ ! -f "$SOURCE_DIR/$FILE" ]; then
    echo "Error: File $SOURCE_DIR/$FILE not found"
    exit 1
fi

# Extract title from HTML
TITLE=$(grep -oP '(?<=<title>)[^<]+' "$SOURCE_DIR/$FILE" | head -1)
if [ -z "$TITLE" ]; then
    TITLE="New GLP-1 Guide: $(basename $FILE .html | sed 's/glp1-/GLP-1 /g' | sed 's/-/ /g')"
fi

# Extract meta description
DESC=$(grep -oP '(?<=<meta name="description" content=")[^"]+' "$SOURCE_DIR/$FILE" | head -1)

# Build post content
CONTENT="I've put together a new guide on: $TITLE

$DESC

Full guide available at: https://jabbitapp.com/$FILE

Disclaimer: This is for informational purposes only. Always consult your healthcare provider before making changes to your medication regimen.

Questions? Let me know in the comments!"

# Check for credentials
if [ ! -f "$DATA_DIR/reddit-credentials.env" ]; then
    echo "Error: Reddit credentials not found at $DATA_DIR/reddit-credentials.env"
    echo "Create it with: REDDIT_CLIENT_ID=xxx REDDIT_CLIENT_SECRET=xxx REDDIT_USERNAME=xxx REDDIT_PASSWORD=xxx"
    exit 1
fi

# Load credentials
source "$DATA_DIR/reddit-credentials.env"

echo "[$(date)] Posting to r/$SUBREDDIT: $TITLE" | tee -a "$LOG_FILE"

# Get access token
TOKEN_RESPONSE=$(curl -s -X POST "https://www.reddit.com/api/v1/access_token" \
    -u "$REDDIT_CLIENT_ID:$REDDIT_CLIENT_SECRET" \
    -d "grant_type=password" \
    -d "username=$REDDIT_USERNAME" \
    -d "password=$REDDIT_PASSWORD")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -oP '"access_token"\s*:\s*"\K[^"]+' | head -1)

if [ -z "$ACCESS_TOKEN" ]; then
    echo "Error: Failed to get Reddit access token"
    echo "$TOKEN_RESPONSE"
    exit 1
fi

# Post to subreddit
POST_RESPONSE=$(curl -s -X POST "https://oauth.reddit.com/r/$SUBREDDIT/submit" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"kind\": \"self\", \"title\": \"$TITLE\", \"text\": \"$CONTENT\"}")

# Check success
if echo "$POST_RESPONSE" | grep -q '"id"'; then
    POST_ID=$(echo "$POST_RESPONSE" | grep -oP '"id"\s*:\s*"\K[^"]+' | head -1)
    echo "Success! Posted: https://reddit.com/$SUBREDDIT/comments/$POST_ID"
    echo "[$(date)] Posted $TITLE to r/$SUBREDDIT - https://reddit.com/$SUBREDDIT/comments/$POST_ID" >> "$LOG_FILE"
else
    echo "Error posting to Reddit"
    echo "$POST_RESPONSE"
fi
