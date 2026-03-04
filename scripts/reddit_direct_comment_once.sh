#!/usr/bin/env bash
# Reddit Direct Comment Script
# Posts value-first comments using NEW-ACCOUNT conservative opportunity filter.
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"

# Authenticated Reddit actions are MANUAL-ONLY by policy.
if [ "${REDDIT_MANUAL_AUTH:-}" != "true" ]; then
  echo "error: auth is manual-only (set REDDIT_MANUAL_AUTH=true)" >&2
  exit 2
fi
if [ "${REDDIT_MANUAL_POST:-}" != "true" ]; then
  echo "error: posting is manual-only (set REDDIT_MANUAL_POST=true)" >&2
  exit 2
fi
if [ "${REDDIT_QUALITY_GATE:-}" != "approved" ]; then
  echo "error: quality gate not approved (set REDDIT_QUALITY_GATE=approved)" >&2
  exit 2
fi
if ! [ -t 0 ]; then
  echo "error: refusing non-interactive auth run" >&2
  exit 2
fi

source "$WS/scripts/proxy.env" 2>/dev/null || true
if [ -f "$WS/scripts/reddit.env" ]; then
  # shellcheck disable=SC1090
  source "$WS/scripts/reddit.env"
fi
source "$WS/scripts/reddit_ladder_params.sh" env
REDDIT_USERNAME="${REDDIT_USERNAME:-LifespanMaxer}"

COOKIE=$(tr -d '[:space:]' < "$WS/.reddit-session" 2>/dev/null || true)
if [ -z "$COOKIE" ]; then
  echo "error: missing .reddit-session cookie" >&2
  exit 2
fi
UA='Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'

# Stable auth path only (no rotation).
AUTH_PROXY="${AUTH_REDDIT_PROXY_URL:-${REDDIT_PROXY_URL:-}}"
if [ -z "${AUTH_PROXY:-}" ]; then
  echo "error: missing AUTH_REDDIT_PROXY_URL (stable auth IP required)" >&2
  exit 2
fi

echo "ladder_day=$REDDIT_WARMUP_DAY slot=$REDDIT_CYCLE_SLOT max_comments=$MAX_COMMENTS"

# Fetch modhash for commenting
TMP=$(mktemp)
code=$(curl -s -o "$TMP" -w '%{http_code}' -x "$AUTH_PROXY" \
  -H "Cookie: reddit_session=${COOKIE}" -H "User-Agent: $UA" -H 'Accept: application/json' \
  --max-time 30 "https://www.reddit.com/r/Mounjaro/new.json?limit=1")
MODHASH=$(python3 - <<'PY' "$TMP"
import json,sys
j=json.load(open(sys.argv[1]))
print((j.get('data') or {}).get('modhash',''))
PY
) || MODHASH=""
rm -f "$TMP"

if [ -z "$MODHASH" ]; then
  echo "ERROR: could not fetch modhash"
  exit 1
fi

COMMENTS_POSTED=0
SEEN_SUBS=""

# Refresh blacklist from recent negative-scored comments so we avoid re-engaging bad-fit threads.
bash "$WS/scripts/reddit_negative_feedback_blacklist.sh" >/tmp/reddit-blacklist.out 2>/dev/null || true

echo "Finding conservative opportunities for new account..."
OPP_FILE=$(mktemp)
python3 "$WS/scripts/find_reddit_opportunities_newacct.py" > "$OPP_FILE" 2>/dev/null || true

if [ ! -s "$OPP_FILE" ]; then
  echo "comments_posted=0 reason=no_opportunities"
  rm -f "$OPP_FILE"
  exit 0
fi

while IFS='|' read -r POST_ID TITLE BODY SUB PERMALINK NUM_COMMENTS AGE_HOURS; do
  [ "$COMMENTS_POSTED" -ge "$MAX_COMMENTS" ] && break
  [ -z "$POST_ID" ] && continue
  [ -z "$SUB" ] && continue

  # One comment per subreddit per run to reduce behavioral footprint.
  if echo " $SEEN_SUBS " | grep -q " $SUB "; then
    continue
  fi

  # Generate comment using python helper (safe env passing)
  COMMENT=$(POST_TITLE="$TITLE" POST_BODY="$BODY" python3 - <<'PY'
import os,sys
sys.path.insert(0, '/home/jabbit/.openclaw/workspace/scripts')
from reddit_comment_generator import build_value_comment
post = {
    'title': os.getenv('POST_TITLE',''),
    'selftext': os.getenv('POST_BODY',''),
}
print(build_value_comment(post))
PY
  ) || COMMENT=""

  if [ -z "$COMMENT" ]; then
    continue
  fi

  RESULT=$(curl -s -x "$AUTH_PROXY" \
    -H "Cookie: reddit_session=${COOKIE}" -H "User-Agent: $UA" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "thing_id=t3_${POST_ID}" \
    --data-urlencode "text=${COMMENT}" \
    --data-urlencode "uh=${MODHASH}" \
    --data-urlencode 'api_type=json' \
    --max-time 30 "https://www.reddit.com/api/comment")

  if echo "$RESULT" | python3 -c "import json,sys; j=json.load(sys.stdin); exit(1 if j.get('json',{}).get('errors') else 0)" 2>/dev/null; then
    COMMENTS_POSTED=$((COMMENTS_POSTED+1))
    SEEN_SUBS="$SEEN_SUBS $SUB"
    echo "COMMENT ok post=$POST_ID r/$SUB comments=$NUM_COMMENTS age_h=$AGE_HOURS"
    # Intra-run jitter to avoid burst behavior.
    sleep $((RANDOM%90+45))
  else
    ERR=$(echo "$RESULT" | python3 -c "import json,sys; j=json.load(sys.stdin); print(j.get('json',{}).get('errors',[]))" 2>/dev/null || echo "[]")
    echo "COMMENT fail post=$POST_ID r/$SUB errors=$ERR"
  fi

done < "$OPP_FILE"

rm -f "$OPP_FILE"

echo "comments_posted=$COMMENTS_POSTED"
