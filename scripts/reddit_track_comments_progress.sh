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
COOKIE=$(tr -d '[:space:]' < "$WS/.reddit-session")
UA='Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'

TMP=$(mktemp)
code=$(curl -s -o "$TMP" -w '%{http_code}' -x "$REDDIT_PROXY_URL" \
  -H "Cookie: reddit_session=${COOKIE}" -H "User-Agent: $UA" -H 'Accept: application/json' \
  --max-time 30 "https://www.reddit.com/user/${TARGET_USER}/comments.json?limit=${LIMIT}&raw_json=1")

if [ "$code" != "200" ]; then
  echo "ERROR: comments fetch failed HTTP $code"
  rm -f "$TMP"
  exit 1
fi

python3 - <<'PY' "$TMP" "$STATE_FILE" "$TARGET_USER"
import json,sys,datetime
src,state,user=sys.argv[1],sys.argv[2],sys.argv[3]
now=datetime.datetime.utcnow().replace(microsecond=0).isoformat()+"Z"
j=json.load(open(src))
children=((j.get('data') or {}).get('children') or [])
current=[]
for ch in children:
    d=ch.get('data') or {}
    cid=d.get('id','')
    if not cid: continue
    current.append({
        'id': cid,
        'score': int(d.get('score') or 0),
        'subreddit': d.get('subreddit',''),
        'permalink': 'https://reddit.com'+(d.get('permalink') or ''),
        'created_utc': int(d.get('created_utc') or 0),
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

out={'tracked_user':user,'updated_at_utc':now,'count':len(current),'comments':current}
json.dump(out,open(state,'w'),indent=2)

# Print compact summary
print(f"TRACKING: u/{user} comments={len(current)} updated={now}")
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
