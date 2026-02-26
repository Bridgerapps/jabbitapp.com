#!/usr/bin/env bash
# Reddit Direct Comment Script
# Posts value-first comments on relevant posts
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
source "$WS/scripts/proxy.env"
source "$WS/scripts/reddit_ladder_params.sh" env

COOKIE=$(tr -d '[:space:]' < "$WS/.reddit-session")
UA='Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'

echo "ladder_day=$REDDIT_WARMUP_DAY slot=$REDDIT_CYCLE_SLOT max_comments=$MAX_COMMENTS"

# Fetch modhash for commenting
TMP=$(mktemp)
code=$(curl -s -o "$TMP" -w '%{http_code}' -x "$REDDIT_PROXY_URL" \
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

# Target subreddits
TARGET_SUBS="Mounjaro Ozempic Zepbound Semaglutide Wegovy Peptides longevity biohackers"

COMMENTS_POSTED=0

# Run the opportunity finder to get posts to comment on
echo "Finding comment opportunities..."
OPPORTUNITIES=$(python3 "$WS/scripts/find_reddit_opportunities.py" 2>/dev/null | head -20 || echo "")

for SUB in $TARGET_SUBS; do
  [ $COMMENTS_POSTED -ge $MAX_COMMENTS ] && break
  
  RESP=$(mktemp)
  curl -s -o "$RESP" -x "$REDDIT_PROXY_URL" \
    -H "Cookie: reddit_session=${COOKIE}" -H "User-Agent: $UA" -H 'Accept: application/json' \
    --max-time 30 "https://www.reddit.com/r/${SUB}/new.json?limit=50" > "$RESP"
  
  # Find posts to comment on
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
    if d.get('author','')=='LongevityProtocol': continue
    age_h=(now-d.get('created_utc',now))/3600
    if age_h>24: continue
    if d.get('num_comments',0)<2: continue
    if d.get('num_comments',0)>80: continue
    candidates.append((d.get('id'), d.get('title',''), d.get('selftext','')))
random.shuffle(candidates)
for pid,title,body in candidates[:5]:
    print(f"{pid}|{title[:100]}|{body[:200]}")
PY
)
  
  for LINE in $IDS; do
    [ $COMMENTS_POSTED -ge $MAX_COMMENTS ] && break
    POST_ID=$(echo "$LINE" | cut -d'|' -f1)
    TITLE=$(echo "$LINE" | cut -d'|' -f2)
    BODY=$(echo "$LINE" | cut -d'|' -f3)
    
    # Generate comment using the Python generator
    COMMENT=$(python3 -c "
import sys, json
sys.path.insert(0, '$WS/scripts')
from reddit_comment_generator import build_value_comment
post = {'title': '''$TITLE''', 'selftext': '''$BODY'''}
print(build_value_comment(post))
" 2>/dev/null || echo "")
    
    if [ -z "$COMMENT" ]; then
      continue
    fi
    
    # Post the comment
    RESULT=$(curl -s -x "$REDDIT_PROXY_URL" \
      -H "Cookie: reddit_session=${COOKIE}" -H "User-Agent: $UA" \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      --data-urlencode "thing_id=t3_${POST_ID}" \
      --data-urlencode "text=${COMMENT}" \
      --data-urlencode "uh=${MODHASH}" \
      --data-urlencode 'api_type=json' \
      --max-time 30 "https://www.reddit.com/api/comment")
    
    if echo "$RESULT" | python3 -c "import json,sys; j=json.load(sys.stdin); exit(1 if j.get('json',{}).get('errors') else 0)" 2>/dev/null; then
      COMMENTS_POSTED=$((COMMENTS_POSTED+1))
      echo "COMMENT ok post=$POST_ID r/$SUB"
    else
      echo "COMMENT fail post=$POST_ID r/$SUB"
    fi
  done
  rm -f "$RESP"
done

echo "comments_posted=$COMMENTS_POSTED"
