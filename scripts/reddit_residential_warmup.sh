#!/usr/bin/env bash
# Reddit Residential Warmup Script
# Upvotes relevant posts to build account standing
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"

# Authenticated Reddit actions are MANUAL-ONLY by policy.
if [ "${REDDIT_MANUAL_AUTH:-}" != "true" ]; then
  echo "error: auth is manual-only (set REDDIT_MANUAL_AUTH=true)" >&2
  exit 2
fi
if [ "${REDDIT_MANUAL_VOTE:-}" != "true" ]; then
  echo "error: voting is manual-only (set REDDIT_MANUAL_VOTE=true)" >&2
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

AUTH_PROXY="${AUTH_REDDIT_PROXY_URL:-${REDDIT_PROXY_URL:-}}"
if [ -z "${AUTH_PROXY:-}" ]; then
  echo "error: missing AUTH_REDDIT_PROXY_URL (stable auth IP required)" >&2
  exit 2
fi

# Target subreddits for GLP-1/peptide community
TARGET_SUBS="Mounjaro Ozempic Zepbound Semaglutide Wegovy Peptides longevity biohackers"

echo "ladder_day=$REDDIT_WARMUP_DAY slot=$REDDIT_CYCLE_SLOT max_upvotes=$MAX_UPVOTES"

# Fetch modhash for voting
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

UPVOTED=0
for SUB in $TARGET_SUBS; do
  [ $UPVOTED -ge $MAX_UPVOTES ] && break
  
  RESP=$(mktemp)
  curl -s -o "$RESP" -x "$AUTH_PROXY" \
    -H "Cookie: reddit_session=${COOKIE}" -H "User-Agent: $UA" -H 'Accept: application/json' \
    --max-time 30 "https://www.reddit.com/r/${SUB}/new.json?limit=30"
  
  # Find posts to upvote (skip our own, low engagement, too old)
  IDS=$(python3 - <<PY "$RESP"
import json,sys,random
from datetime import datetime, UTC
try:
    j=json.load(open(sys.argv[1]))
except:
    sys.exit(0)
now=datetime.now(UTC).timestamp()
candidates=[]
for p in (j.get('data') or {}).get('children',[]):
    d=p.get('data',{})
    if d.get('author','')=='${REDDIT_USERNAME}': continue
    if d.get('score',0)<1: continue
    age_h=(now-d.get('created_utc',now))/3600
    if age_h>48: continue
    if d.get('num_comments',0)<2: continue
    candidates.append(d.get('id'))
random.shuffle(candidates)
print(' '.join(candidates[:2]))
PY
)
  
  for POST_ID in $IDS; do
    [ $UPVOTED -ge $MAX_UPVOTES ] && break
    curl -s -x "$AUTH_PROXY" \
      -H "Cookie: reddit_session=${COOKIE}" -H "User-Agent: $UA" \
      --data "id=t3_${POST_ID}&dir=1&uh=${MODHASH}&api_type=json" \
      --max-time 15 "https://www.reddit.com/api/vote" && UPVOTED=$((UPVOTED+1)) && echo "upvoted r/$SUB $POST_ID"
  done
  rm -f "$RESP"
done

echo "upvoted=$UPVOTED"
