#!/usr/bin/env bash
set -euo pipefail

# Creates a small “approval pack” for Jon: top 3 awaiting_owner sends with subject + destination + where to find the copy.
# Output is EPHEMERAL and safe: data/status/*.md (not WORKLOG).

ROOT="/home/jabbit/.openclaw/workspace"
LATEST_JSON="$ROOT/data/status/manual-growth-loop-awaiting-owner-top3-latest.json"

if [ ! -f "$LATEST_JSON" ]; then
  echo "ERROR: missing $LATEST_JSON (run generate-awaiting-owner-top3.sh first)" >&2
  exit 1
fi

TS="$(date -u +%Y-%m-%dT%H%M%SZ)"
OUT="$ROOT/data/status/manual-growth-loop-owner-approval-pack-${TS}.md"

python3 - <<'PY' "$LATEST_JSON" "$OUT" "$TS"
import json, sys
latest_json, out_path, ts = sys.argv[1], sys.argv[2], sys.argv[3]

with open(latest_json,'r',encoding='utf-8') as f:
    data=json.load(f)

top3=data.get('top3',[])
lines=[]
lines.append(f"owner-approval-pack")
lines.append(f"updatedUtc: {data.get('updatedUtc','')}\n")
lines.append("Approve any of these for manual send (reply with APPROVE: <ids>):\n")

if not top3:
    lines.append("- (none)\n")
else:
    for item in top3:
        sid=item.get('sendQueueId','')
        channel=item.get('channel','')
        to=item.get('to','')
        subject=item.get('subject','')
        brief=item.get('brief','')
        lines.append(f"- id: {sid}")
        lines.append(f"  channel: {channel}")
        lines.append(f"  to: {to}")
        if subject:
            lines.append(f"  subject: {subject}")
        if brief:
            lines.append(f"  copy: {brief} (search within for id={sid})")
        lines.append("")

with open(out_path,'w',encoding='utf-8') as f:
    f.write("\n".join(lines).rstrip()+"\n")

print(f"WROTE: {out_path}")
PY

ln -sf "$(basename "$OUT")" "$ROOT/data/status/manual-growth-loop-owner-approval-pack-latest.md"
echo "UPDATED: $ROOT/data/status/manual-growth-loop-owner-approval-pack-latest.md -> $(basename "$OUT")"