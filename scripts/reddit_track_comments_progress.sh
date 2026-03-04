#!/usr/bin/env bash
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"

OUT_DIR="$WS/data/reddit"
STATE_FILE="$OUT_DIR/poodpound-comment-progress.json"
mkdir -p "$OUT_DIR"

# shellcheck disable=SC1091
source "$WS/scripts/proxy.env"
if [ -f "$WS/scripts/reddit.env" ]; then
  # shellcheck disable=SC1090
  source "$WS/scripts/reddit.env"
fi

TARGET_USER="${1:-PoodPound}"
LIMIT="${2:-30}"
USE_COOKIE_AUTH="${USE_COOKIE_AUTH:-false}"

# If cookie auth is enabled, treat it as an authenticated action => MANUAL-ONLY.
if [ "$USE_COOKIE_AUTH" = "true" ]; then
  if [ "${REDDIT_MANUAL_AUTH:-}" != "true" ]; then
    echo "TRACKING_BLOCKED: manual_only (set REDDIT_MANUAL_AUTH=true)"
    exit 2
  fi
  if ! [ -t 0 ]; then
    echo "TRACKING_BLOCKED: noninteractive"
    exit 2
  fi
fi

COOKIE=""
if [ "$USE_COOKIE_AUTH" = "true" ] && [ -f "$WS/.reddit-session" ]; then
  COOKIE=$(tr -d '[:space:]' < "$WS/.reddit-session")
fi
UA='Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'

TMP=$(mktemp)
CURL_ARGS=(-s -o "$TMP" -w '%{http_code}' -x "$REDDIT_PROXY_URL" -H "User-Agent: $UA" -H 'Accept: application/json' --max-time 30)
if [ -n "$COOKIE" ]; then
  CURL_ARGS+=(-H "Cookie: reddit_session=${COOKIE}")
fi
code=$(curl "${CURL_ARGS[@]}" "https://www.reddit.com/user/${TARGET_USER}/comments.json?limit=${LIMIT}&raw_json=1")

if [ "$code" != "200" ]; then
  echo "ERROR: comments fetch failed HTTP $code"
  rm -f "$TMP"
  exit 1
fi

TRACK_RECENT_HOURS="${TRACK_RECENT_HOURS:-96}"

python3 - <<'PY' "$TMP" "$STATE_FILE" "$TARGET_USER" "$TRACK_RECENT_HOURS"
import json,sys,datetime,time
src,state,user,recent_h=sys.argv[1],sys.argv[2],sys.argv[3],float(sys.argv[4])
now_dt=datetime.datetime.now(datetime.UTC)
now=now_dt.timestamp()
cutoff=now-(recent_h*3600)
now_iso=now_dt.replace(microsecond=0).isoformat().replace('+00:00','Z')
j=json.load(open(src))
children=((j.get('data') or {}).get('children') or [])
current=[]
for ch in children:
    d=ch.get('data') or {}
    cid=d.get('id','')
    created=float(d.get('created_utc') or 0)
    if not cid: continue
    if created < cutoff: continue
    current.append({
        'id': cid,
        'score': int(d.get('score') or 0),
        'subreddit': d.get('subreddit',''),
        'permalink': 'https://reddit.com'+(d.get('permalink') or ''),
        'created_utc': int(created),
        'body': (d.get('body') or '').replace('\n',' ')[:160]
    })

old_map={}
if True:
    try:
        old=json.load(open(state))
        for e in old.get('comments',[]):
            old_map[e.get('id')]=e
    except Exception:
        pass

changes=[]
for e in current:
    prev=old_map.get(e['id'])
    if prev is None:
        changes.append({'id':e['id'],'delta':None,'score':e['score'],'new':True,'permalink':e['permalink'],'subreddit':e['subreddit']})
    else:
        d=e['score']-int(prev.get('score',0))
        if d!=0:
            changes.append({'id':e['id'],'delta':d,'score':e['score'],'new':False,'permalink':e['permalink'],'subreddit':e['subreddit']})

out={'tracked_user':user,'updated_at_utc':now_iso,'recent_hours':recent_h,'count':len(current),'comments':current}
json.dump(out,open(state,'w'),indent=2)

# Print compact summary
print(f"TRACKING: u/{user} recent_hours={int(recent_h)} comments={len(current)} updated={now_iso}")
if not changes:
    print('CHANGES: none since last snapshot')
else:
    print(f"CHANGES: {len(changes)}")
    # prioritize biggest gains
    def key(x):
        if x['delta'] is None:
            return -999
        return -x['delta']
    for c in sorted(changes,key=key)[:10]:
        if c['new']:
            print(f"NEW  score={c['score']} r/{c['subreddit']} {c['permalink']}")
        else:
            sign='+' if c['delta']>0 else ''
            print(f"DELTA {sign}{c['delta']} -> {c['score']} r/{c['subreddit']} {c['permalink']}")
PY

rm -f "$TMP"
