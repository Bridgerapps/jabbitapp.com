#!/usr/bin/env bash
# Post one specific Reddit comment to a post id.
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <post_id> <comment_text>" >&2
  exit 1
fi

POST_ID="$1"
COMMENT_TEXT="$2"
WS="/home/jabbit/.openclaw/workspace"

# Hard safety gate: only allow posting when explicitly approved by quality-review step.
if [ "${REDDIT_QUALITY_GATE:-}" != "approved" ]; then
  echo "error: quality gate not approved (set REDDIT_QUALITY_GATE=approved)" >&2
  exit 1
fi

source "$WS/scripts/proxy.env" 2>/dev/null || true
COOKIE=""
if [ -f "$WS/.reddit-session" ]; then
  COOKIE=$(tr -d '[:space:]' < "$WS/.reddit-session")
fi
if [ -z "$COOKIE" ]; then
  echo "error: missing reddit_session cookie" >&2
  exit 1
fi

UA='Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'
args=(-sS -A "$UA" -H "Accept: application/json")
[ -n "${REDDIT_PROXY_URL:-}" ] && args=(-x "$REDDIT_PROXY_URL" "${args[@]}")

# fetch modhash
mh=$(curl "${args[@]}" -H "Cookie: reddit_session=${COOKIE}" "https://www.reddit.com/api/me.json?raw_json=1" \
  | jq -r '.data.modhash // empty')
if [ -z "$mh" ]; then
  # fallback path
  mh=$(curl "${args[@]}" -H "Cookie: reddit_session=${COOKIE}" "https://www.reddit.com/r/Mounjaro/new.json?limit=1" \
    | jq -r '.data.modhash // empty')
fi
if [ -z "$mh" ]; then
  echo "error: unable to fetch modhash" >&2
  exit 1
fi

resp=$(curl "${args[@]}" \
  -H "Cookie: reddit_session=${COOKIE}" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "thing_id=t3_${POST_ID}" \
  --data-urlencode "text=${COMMENT_TEXT}" \
  --data-urlencode "uh=${mh}" \
  --data-urlencode 'api_type=json' \
  "https://www.reddit.com/api/comment")

errs=$(printf '%s' "$resp" | jq -c '.json.errors // []')
if [ "$errs" != "[]" ]; then
  echo "error: reddit returned errors: $errs" >&2
  exit 1
fi

name=$(printf '%s' "$resp" | jq -r '.json.data.things[0].data.name // empty')
echo "posted=${name:-ok} post_id=${POST_ID}"
