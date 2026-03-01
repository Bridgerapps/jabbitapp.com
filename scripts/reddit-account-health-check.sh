#!/usr/bin/env bash
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
source "$WS/scripts/proxy.env" 2>/dev/null || true
source "$WS/scripts/reddit.env" 2>/dev/null || true
COOKIE=$(tr -d '[:space:]' < "$WS/.reddit-session" 2>/dev/null || true)
UA="Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36"
username="${REDDIT_USERNAME:-LifespanMaxer}"

args=(-sS -A "$UA")
[ -n "${REDDIT_PROXY_URL:-}" ] && args=(-x "$REDDIT_PROXY_URL" "${args[@]}")

me=$(curl "${args[@]}" -H "Cookie: reddit_session=${COOKIE}" "https://www.reddit.com/api/me.json")
me_name=$(printf "%s" "$me" | jq -r '.data.name // empty')
me_suspended=$(printf "%s" "$me" | jq -r '.data.is_suspended // false')

# public visibility check (without cookie)
pub=$(curl "${args[@]}" "https://www.reddit.com/user/${username}/about.json?raw_json=1")
pub_err=$(printf "%s" "$pub" | jq -r '.error // 0')

ok=0
for s in Mounjaro Ozempic Zepbound; do
  code=$(curl "${args[@]}" -o /dev/null -w "%{http_code}" -H "Cookie: reddit_session=${COOKIE}" "https://www.reddit.com/r/$s/new.json?limit=1")
  [ "$code" = "200" ] && ok=$((ok+1))
done

if [ -z "$me_name" ]; then
  echo "Reddit session may be expired/invalid. Send a fresh reddit_session cookie."
elif [ "$me_name" != "$username" ]; then
  echo "Reddit auth mismatch: expected=$username got=$me_name. Rotate cookie now."
elif [ "$me_suspended" = "true" ]; then
  echo "Reddit account alert: account appears suspended. Pause actions and appeal."
elif [ "$pub_err" = "404" ]; then
  echo "Reddit visibility alert: public profile returns 404 (possible shadow restriction)."
elif [ "$ok" -lt 2 ]; then
  echo "Reddit access alert: subreddit_ok=${ok}/3 (proxy/session instability)."
else
  echo NO_REPLY
fi
