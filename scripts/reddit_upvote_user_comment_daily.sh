#!/usr/bin/env bash
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

STATE_DIR="$WS/data/reddit"
STATE_FILE="$STATE_DIR/user-comment-upvote-state.json"
mkdir -p "$STATE_DIR"

# shellcheck disable=SC1091
source "$WS/scripts/proxy.env"
if [ -f "$WS/scripts/reddit.env" ]; then
  # shellcheck disable=SC1090
  source "$WS/scripts/reddit.env"
fi

TARGET_USER="${1:-${TARGET_USER:-PoodPound}}"
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

# Get modhash
TMP=$(mktemp)
code=$(curl -s -o "$TMP" -w '%{http_code}' -x "$AUTH_PROXY" \
  -H "Cookie: reddit_session=${COOKIE}" -H "User-Agent: $UA" -H 'Accept: application/json' \
  --max-time 30 "https://www.reddit.com/r/Mounjaro/new.json?limit=1")

if [ "$code" != "200" ]; then
  echo "ERROR: modhash probe failed HTTP $code"
  rm -f "$TMP"
  exit 1
fi

MODHASH=$(python3 - <<'PY' "$TMP"
import json,sys
j=json.load(open(sys.argv[1]))
print((j.get('data') or {}).get('modhash',''))
PY
)
rm -f "$TMP"

if [ -z "$MODHASH" ]; then
  echo "ERROR: could not fetch modhash"
  exit 1
fi

LAST_ID=""
if [ -f "$STATE_FILE" ]; then
  LAST_ID=$(python3 - <<'PY' "$STATE_FILE"
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    print(d.get('last_upvoted_comment_id',''))
except Exception:
    print('')
PY
)
fi

RESP=$(mktemp)
code=$(curl -s -o "$RESP" -w '%{http_code}' -x "$AUTH_PROXY" \
  -H "Cookie: reddit_session=${COOKIE}" -H "User-Agent: $UA" -H 'Accept: application/json' \
  --max-time 30 "https://www.reddit.com/user/${TARGET_USER}/comments.json?limit=50")

if [ "$code" != "200" ]; then
  echo "ERROR: user comments fetch failed HTTP $code"
  rm -f "$RESP"
  exit 1
fi

PICK=$(python3 - <<'PY' "$RESP" "$LAST_ID"
import json,sys,time
j=json.load(open(sys.argv[1]))
last=sys.argv[2]
now=time.time()
for p in (j.get('data') or {}).get('children',[]):
    d=p.get('data',{})
    cid=d.get('id','')
    if not cid:
        continue
    # only very recent comments (<7 days)
    if now - float(d.get('created_utc',now)) > 7*86400:
        continue
    if cid==last:
        continue
    # skip already-upvoted comments by account if score already huge? keep simple: pick newest not previously upvoted
    sub=d.get('subreddit','?')
    link=d.get('permalink','')
    body=(d.get('body') or '').replace('\t',' ').replace('\n',' ')[:140]
    print(cid + "\t" + sub + "\t" + link + "\t" + body)
    break
PY
)
rm -f "$RESP"

if [ -z "$PICK" ]; then
  echo "NOOP: no new eligible comment to upvote for u/${TARGET_USER}"
  exit 0
fi

COMMENT_ID=$(printf '%s' "$PICK" | cut -f1)
SUB=$(printf '%s' "$PICK" | cut -f2)
LINK=$(printf '%s' "$PICK" | cut -f3)
BODY=$(printf '%s' "$PICK" | cut -f4-)

curl -s -x "$AUTH_PROXY" \
  -H "Cookie: reddit_session=${COOKIE}" -H "User-Agent: $UA" \
  --data "id=t1_${COMMENT_ID}&dir=1&uh=${MODHASH}&api_type=json" \
  --max-time 20 "https://www.reddit.com/api/vote" >/dev/null

python3 - <<'PY' "$STATE_FILE" "$COMMENT_ID" "$TARGET_USER"
import json,sys,datetime
path,cid,user=sys.argv[1],sys.argv[2],sys.argv[3]
out={
  "target_user": user,
  "last_upvoted_comment_id": cid,
  "last_upvoted_at_utc": datetime.datetime.utcnow().replace(microsecond=0).isoformat()+"Z"
}
json.dump(out,open(path,'w'),indent=2)
print(f"UPVOTED: t1_{cid}")
PY

echo "u/${TARGET_USER} r/${SUB} https://reddit.com${LINK} :: ${BODY}"
