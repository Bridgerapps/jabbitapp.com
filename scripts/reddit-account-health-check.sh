#!/usr/bin/env bash
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
source "$WS/scripts/proxy.env" 2>/dev/null || true
source "$WS/scripts/reddit.env" 2>/dev/null || true

COOKIE=$(tr -d '[:space:]' < "$WS/.reddit-session" 2>/dev/null || true)
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
username="${REDDIT_USERNAME:-LifespanMaxer}"

# Safety/rate-limit guard to avoid repetitive auth traffic.
STATE_FILE="$WS/data/reddit/.account-health-check.state"
MIN_INTERVAL_SEC="${REDDIT_ACCOUNT_HEALTH_MIN_INTERVAL_SEC:-900}" # 15 min default
mkdir -p "$WS/data/reddit"
now=$(date +%s)
if [ -f "$STATE_FILE" ]; then
  last=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
else
  last=0
fi
if [ $((now - last)) -lt "$MIN_INTERVAL_SEC" ]; then
  echo NO_REPLY
  exit 0
fi
printf "%s" "$now" > "$STATE_FILE"

# Auth checks should use auth proxy; public checks should use discovery proxy.
AUTH_PROXY="${AUTH_REDDIT_PROXY_URL:-${REDDIT_PROXY_URL:-}}"
PUB_PROXY="${DISCOVERY_REDDIT_PROXY_URL:-${REDDIT_PROXY_URL:-}}"

base_args=(-sS --max-time 20 -A "$UA")
auth_args=("${base_args[@]}")
pub_args=("${base_args[@]}")
[ -n "${AUTH_PROXY:-}" ] && auth_args=(-x "$AUTH_PROXY" "${auth_args[@]}")
[ -n "${PUB_PROXY:-}" ] && pub_args=(-x "$PUB_PROXY" "${pub_args[@]}")

me_name=""
me_suspended="false"
if [ -n "$COOKIE" ]; then
  me=$(curl "${auth_args[@]}" -H "Cookie: reddit_session=${COOKIE}" "https://www.reddit.com/api/me.json?raw_json=1" || true)
  me_name=$(printf "%s" "$me" | jq -r '.data.name // empty' 2>/dev/null || true)
  me_suspended=$(printf "%s" "$me" | jq -r '.data.is_suspended // false' 2>/dev/null || echo false)
fi

# Public visibility check (no cookie).
pub=$(curl "${pub_args[@]}" "https://www.reddit.com/user/${username}/about.json?raw_json=1" || true)
pub_err=$(printf "%s" "$pub" | jq -r '.error // 0' 2>/dev/null || echo 0)

# Optional subreddit probe checks are OFF by default for safety.
sub_checks_ok=0
if [ "${REDDIT_ACCOUNT_HEALTH_SUB_CHECKS:-false}" = "true" ] && [ -n "$COOKIE" ]; then
  ok=0
  for s in Mounjaro Ozempic Zepbound; do
    code=$(curl "${auth_args[@]}" -o /dev/null -w "%{http_code}" -H "Cookie: reddit_session=${COOKIE}" "https://www.reddit.com/r/$s/new.json?limit=1" || echo 000)
    [ "$code" = "200" ] && ok=$((ok+1))
  done
  [ "$ok" -ge 2 ] && sub_checks_ok=1
else
  sub_checks_ok=1
fi

if [ -z "$COOKIE" ] || [ -z "$me_name" ]; then
  echo "Reddit session may be expired/invalid. Send a fresh reddit_session cookie."
elif [ "$me_name" != "$username" ]; then
  echo "Reddit auth mismatch: expected=$username got=$me_name. Rotate cookie now."
elif [ "$me_suspended" = "true" ]; then
  echo "Reddit account alert: account appears suspended. Pause actions and appeal."
elif [ "$pub_err" = "404" ]; then
  echo "Reddit visibility alert: public profile returns 404 (possible shadow restriction)."
elif [ "$sub_checks_ok" -ne 1 ]; then
  echo "Reddit access alert: subreddit checks degraded (proxy/session instability)."
else
  echo NO_REPLY
fi
