#!/usr/bin/env bash
# Best-effort: subscribe current Reddit account to subreddits where Shotsy is mentioned today.
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
JSON="$WS/data/reddit/shotsy-opportunities.json"
WATCHLIST="$WS/data/reddit/shotsy-watch-subreddits.txt"
COMMUNITY_WATCHLIST="$WS/data/reddit/community-watch-subreddits.txt"

[ -f "$JSON" ] || [ -f "$WATCHLIST" ] || [ -f "$COMMUNITY_WATCHLIST" ] || { echo "subscribed=0 checked=0"; exit 0; }

source "$WS/scripts/proxy.env" 2>/dev/null || true
COOKIE=""
if [ -f "$WS/.reddit-session" ]; then
  COOKIE=$(tr -d '[:space:]' < "$WS/.reddit-session")
fi
[ -n "$COOKIE" ] || { echo "subscribed=0 checked=0"; exit 0; }

UA='Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'
args=(-sS -A "$UA" -H 'Accept: application/json')
[ -n "${REDDIT_PROXY_URL:-}" ] && args=(-x "$REDDIT_PROXY_URL" "${args[@]}")

# Fetch modhash
mh=$(curl "${args[@]}" -H "Cookie: reddit_session=${COOKIE}" "https://www.reddit.com/api/me.json?raw_json=1" | jq -r '.data.modhash // empty')
[ -n "$mh" ] || { echo "subscribed=0 checked=0"; exit 0; }

MAX_SUBS=${SHOTSY_SUBSCRIBE_MAX:-120}
if [ -f "$WATCHLIST" ] || [ -f "$COMMUNITY_WATCHLIST" ]; then
  mapfile -t subs < <(
    {
      [ -f "$WATCHLIST" ] && grep -v '^\s*$' "$WATCHLIST"
      [ -f "$COMMUNITY_WATCHLIST" ] && grep -v '^\s*$' "$COMMUNITY_WATCHLIST"
    } | awk '!seen[$0]++' | head -n "$MAX_SUBS"
  )
else
  mapfile -t subs < <(jq -r '.tracked_subreddits[]? // empty' "$JSON" | head -n "$MAX_SUBS")
fi
count=0
checked=0
for s in "${subs[@]}"; do
  [ -n "$s" ] || continue
  checked=$((checked+1))
  # action=sub is idempotent from user perspective.
  resp=$(curl "${args[@]}" \
    -H "Cookie: reddit_session=${COOKIE}" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "action=sub" \
    --data-urlencode "sr_name=$s" \
    --data-urlencode "uh=$mh" \
    --data-urlencode 'api_type=json' \
    "https://www.reddit.com/api/subscribe" || true)
  errs=$(printf '%s' "$resp" | jq -c '.json.errors // []' 2>/dev/null || echo '[]')
  if [ "$errs" = "[]" ]; then
    count=$((count+1))
  fi
  sleep 1
done

echo "subscribed=$count checked=$checked"
