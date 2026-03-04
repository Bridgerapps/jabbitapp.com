#!/usr/bin/env bash
# Build blacklist of posts where our recent comments have negative score.
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
mkdir -p "$WS/data/reddit"
OUT="$WS/data/reddit/negative-post-blacklist.txt"
TMP=$(mktemp)

source "$WS/scripts/proxy.env" 2>/dev/null || true
source "$WS/scripts/reddit.env" 2>/dev/null || true
# Policy: this script must be safe for unattended runs (public-only; no cookie reads).
COOKIE=""
UA='Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'
USERNAME="${REDDIT_USERNAME:-LifespanMaxer}"

args=(-sS -A "$UA" -H "Accept: application/json")
[ -n "${REDDIT_PROXY_URL:-}" ] && args=(-x "$REDDIT_PROXY_URL" "${args[@]}")

resp=$(curl "${args[@]}" "https://www.reddit.com/user/${USERNAME}/comments.json?limit=100&raw_json=1" || true)
printf '%s' "$resp" > "$TMP"

python3 - <<'PY' "$TMP" "$OUT"
import json,sys
src,out=sys.argv[1],sys.argv[2]
try:
    j=json.load(open(src))
except Exception:
    open(out,'a').close()
    raise SystemExit(0)
children=((j.get('data') or {}).get('children') or [])
bad=set()
for c in children:
    d=(c.get('data') or {})
    score=d.get('score',0) or 0
    if score < 0:
        lid=(d.get('link_id') or '').replace('t3_','').strip()
        pid=(d.get('parent_id') or '').replace('t3_','').strip()
        if lid: bad.add(lid)
        if pid and d.get('parent_id','').startswith('t3_'): bad.add(pid)

# preserve existing ids too
existing=set()
try:
    for line in open(out,encoding='utf-8'):
        x=line.strip()
        if x: existing.add(x)
except FileNotFoundError:
    pass
all_ids=sorted(existing|bad)
with open(out,'w',encoding='utf-8') as f:
    for x in all_ids:
        f.write(x+'\n')
print(f"blacklisted={len(all_ids)} newly_added={len((existing|bad)-existing)}")
PY

rm -f "$TMP"
