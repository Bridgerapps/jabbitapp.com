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

# Hard safety gates: explicit quality + explicit manual intent required.
if [ "${REDDIT_QUALITY_GATE:-}" != "approved" ]; then
  echo "error: quality gate not approved (set REDDIT_QUALITY_GATE=approved)" >&2
  exit 1
fi
if [ "${REDDIT_MANUAL_POST:-}" != "true" ]; then
  echo "error: manual post flag missing (set REDDIT_MANUAL_POST=true)" >&2
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
AUTH_PROXY="${AUTH_REDDIT_PROXY_URL:-${REDDIT_PROXY_URL:-}}"
[ -n "${AUTH_PROXY:-}" ] && args=(-x "$AUTH_PROXY" "${args[@]}")

fetch_modhash() {
  curl "${args[@]}" -H "Cookie: reddit_session=${COOKIE}" "https://www.reddit.com/api/me.json?raw_json=1" \
    | jq -r '.data.modhash // empty'
}

# fetch modhash
mh=$(fetch_modhash)
if [ -z "$mh" ]; then
  # one-time auth proxy rotation on blocked/invalid path
  bash "$WS/scripts/reddit-proxy-rotate-target.sh" auth >/dev/null 2>&1 || true
  source "$WS/scripts/proxy.env" 2>/dev/null || true
  AUTH_PROXY="${AUTH_REDDIT_PROXY_URL:-${REDDIT_PROXY_URL:-}}"
  args=(-sS -A "$UA" -H "Accept: application/json")
  [ -n "${AUTH_PROXY:-}" ] && args=(-x "$AUTH_PROXY" "${args[@]}")
  mh=$(fetch_modhash)
fi
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
