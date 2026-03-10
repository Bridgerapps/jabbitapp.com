#!/usr/bin/env bash
set -euo pipefail

LEDGER="/home/jabbit/.openclaw/workspace/data/status/manual-growth-loop-ledger.json"
BRIEF="/home/jabbit/.openclaw/workspace/docs/distribution/send-now-brief-latest.md"

if [ ! -f "$LEDGER" ]; then
  echo "ledger missing: $LEDGER" >&2
  exit 2
fi
if [ ! -f "$BRIEF" ]; then
  echo "brief missing: $BRIEF" >&2
  exit 2
fi

python3 - "$LEDGER" "$BRIEF" <<'PY'
import json,sys,os,time
ledger_path, brief_path = sys.argv[1], sys.argv[2]
with open(ledger_path) as f:
  ledger=json.load(f)
qs=ledger.get('sendQueues',[])
ready=[q for q in qs if q.get('status')=='ready_to_send']
ids=[q.get('id') for q in ready if q.get('id')]

with open(brief_path, 'r', encoding='utf-8') as f:
  brief=f.read()

missing=[i for i in ids if i not in brief]

st=os.stat(brief_path)
age_hours=(time.time()-st.st_mtime)/3600

print(f"ready_to_send: {len(ids)}")
print(f"brief_age_hours: {age_hours:.1f}")
if missing:
  print("MISSING_IDS_IN_BRIEF:")
  for i in missing:
    print("-", i)
  sys.exit(1)

# Soft warning if brief is old; still exit 0
if age_hours > 24:
  print("WARN: brief is older than 24h; consider refreshing (prefer editing existing brief, not creating a new one).")
print("OK: all ready_to_send ids appear in brief")
PY