#!/usr/bin/env bash
# Best-effort: subscribe current Reddit account to subreddits where Shotsy is mentioned today.
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
JSON="$WS/data/reddit/shotsy-opportunities.json"
WATCHLIST="$WS/data/reddit/shotsy-watch-subreddits.txt"
COMMUNITY_WATCHLIST="$WS/data/reddit/community-watch-subreddits.txt"
RESEARCH_WATCHLIST="$WS/data/reddit/research-peptide-biohacking-subs.txt"

[ -f "$JSON" ] || [ -f "$WATCHLIST" ] || [ -f "$COMMUNITY_WATCHLIST" ] || [ -f "$RESEARCH_WATCHLIST" ] || { echo "subscribed=0 checked=0"; exit 0; }

source "$WS/scripts/proxy.env" 2>/dev/null || true
COOKIE=""
if [ -f "$WS/.reddit-session" ]; then
  COOKIE=$(tr -d '[:space:]' < "$WS/.reddit-session")
fi
[ -n "$COOKIE" ] || { echo "subscribed=0 checked=0"; exit 0; }

UA='Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'
args=(-sS -A "$UA" -H 'Accept: application/json')
AUTH_PROXY="${AUTH_REDDIT_PROXY_URL:-${REDDIT_PROXY_URL:-}}"
[ -n "${AUTH_PROXY:-}" ] && args=(-x "$AUTH_PROXY" "${args[@]}")

# Fetch modhash
mh=$(curl "${args[@]}" -H "Cookie: reddit_session=${COOKIE}" "https://www.reddit.com/api/me.json?raw_json=1" | jq -r '.data.modhash // empty')
[ -n "$mh" ] || { echo "subscribed=0 checked=0"; exit 0; }

# Human-like behavior caps (avoid bot-like bursts).
MAX_SUBS=${SHOTSY_SUBSCRIBE_MAX:-120}
PER_RUN_MAX=${SHOTSY_SUBSCRIBE_PER_RUN_MAX:-8}
DAILY_MAX=${SHOTSY_SUBSCRIBE_DAILY_MAX:-16}
SLEEP_MIN=${SHOTSY_SUBSCRIBE_SLEEP_MIN:-4}
SLEEP_MAX=${SHOTSY_SUBSCRIBE_SLEEP_MAX:-14}
STATE_FILE="$WS/data/reddit/subscription-activity.json"
mkdir -p "$WS/data/reddit"

if [ -f "$WATCHLIST" ] || [ -f "$COMMUNITY_WATCHLIST" ] || [ -f "$RESEARCH_WATCHLIST" ]; then
  mapfile -t subs < <(
    {
      [ -f "$WATCHLIST" ] && grep -v '^\s*$' "$WATCHLIST"
      [ -f "$COMMUNITY_WATCHLIST" ] && grep -v '^\s*$' "$COMMUNITY_WATCHLIST"
      [ -f "$RESEARCH_WATCHLIST" ] && grep -v '^\s*$' "$RESEARCH_WATCHLIST"
    } | awk '!seen[$0]++' | head -n "$MAX_SUBS"
  )
else
  mapfile -t subs < <(jq -r '.tracked_subreddits[]? // empty' "$JSON" | head -n "$MAX_SUBS")
fi

# Daily cap state
TODAY=$(date -u +%F)
if [ -f "$STATE_FILE" ]; then
  state_date=$(jq -r '.date // ""' "$STATE_FILE" 2>/dev/null || echo "")
  state_count=$(jq -r '.count // 0' "$STATE_FILE" 2>/dev/null || echo 0)
else
  state_date=""
  state_count=0
fi
if [ "$state_date" != "$TODAY" ]; then
  state_count=0
fi
if [ "$state_count" -ge "$DAILY_MAX" ]; then
  echo "subscribed=0 checked=0 skipped=daily_cap_reached daily_count=$state_count daily_max=$DAILY_MAX"
  exit 0
fi

# Randomize order to avoid repetitive subscribe patterns.
mapfile -t subs < <(printf '%s\n' "${subs[@]}" | awk 'NF' | shuf)

remaining=$((DAILY_MAX - state_count))
run_budget=$PER_RUN_MAX
if [ "$remaining" -lt "$run_budget" ]; then
  run_budget=$remaining
fi

count=0
checked=0
for s in "${subs[@]}"; do
  [ -n "$s" ] || continue
  [ "$checked" -ge "$run_budget" ] && break
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

  # Human-like pacing jitter.
  sleep $((RANDOM%(SLEEP_MAX-SLEEP_MIN+1)+SLEEP_MIN))
done

new_daily_count=$((state_count + count))
jq -n --arg d "$TODAY" --argjson c "$new_daily_count" '{date:$d,count:$c}' > "$STATE_FILE"

echo "subscribed=$count checked=$checked daily_count=$new_daily_count daily_max=$DAILY_MAX"
