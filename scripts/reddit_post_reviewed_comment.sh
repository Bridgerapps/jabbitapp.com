#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <post_id>" >&2
  exit 1
fi

POST_ID="$1"
WS="/home/jabbit/.openclaw/workspace"
QUEUE="$WS/data/reddit/review-queue-latest.json"

if [ ! -f "$QUEUE" ]; then
  echo "error: review queue not found ($QUEUE)"
  exit 1
fi

COMMENT=$(jq -r --arg id "$POST_ID" '.candidates[] | select(.post_id==$id) | .proposed_comment' "$QUEUE" | head -n1)
if [ -z "${COMMENT:-}" ] || [ "$COMMENT" = "null" ]; then
  echo "error: post_id not found in review queue: $POST_ID"
  exit 1
fi

REDDIT_QUALITY_GATE=approved bash "$WS/scripts/reddit_post_comment.sh" "$POST_ID" "$COMMENT"
