#!/usr/bin/env bash
set -euo pipefail

# Auto-demote stale ready_to_send items to awaiting_owner to prevent endless preflight STOP loops.
# Rationale: ready_to_send is for "send now" windows. If an item sits >THRESHOLD_SECONDS,
# it is effectively awaiting owner anyway; demoting unblocks the operator loop.
#
# Safe: local state only (ledger JSON). Reversible by editing ledger.

LEDGER=${1:-/home/jabbit/.openclaw/workspace/data/status/manual-growth-loop-ledger.json}
THRESHOLD_SECONDS=${THRESHOLD_SECONDS:-86400}
DRY=${DRY:-0}
NOW_EPOCH=${NOW_EPOCH:-""}

if [ ! -f "$LEDGER" ]; then
  echo "missing ledger: $LEDGER" >&2
  exit 1
fi

export LEDGER
export THRESHOLD_SECONDS
export DRY
export NOW_EPOCH

python3 - <<'PY'
import json, os, time, datetime

ledger_path = os.environ.get('LEDGER')
threshold = int(os.environ.get('THRESHOLD_SECONDS','86400'))
dry = os.environ.get('DRY','0') == '1'
now_epoch = os.environ.get('NOW_EPOCH')

if now_epoch:
  now = int(now_epoch)
else:
  now = int(time.time())

with open(ledger_path,'r',encoding='utf-8') as f:
  data = json.load(f)

changed = 0
stale_ids = []

# prefer whenUtc then addedUtc

def parse_iso(s):
  if not s:
    return None
  try:
    # accept Z
    if s.endswith('Z'):
      s = s[:-1] + '+00:00'
    return int(datetime.datetime.fromisoformat(s).timestamp())
  except Exception:
    return None

for item in data.get('sendQueues', []):
  if item.get('status') != 'ready_to_send':
    continue
  ts = parse_iso(item.get('whenUtc')) or parse_iso(item.get('addedUtc'))
  if ts is None:
    continue
  age = now - ts
  if age <= threshold:
    continue

  item['status'] = 'awaiting_owner'
  item['awaitingOwnerUtc'] = datetime.datetime.utcfromtimestamp(now).replace(microsecond=0).isoformat() + 'Z'
  item['awaitingOwnerReason'] = 'stale-ready-auto-demote'
  item['updatedUtc'] = item['awaitingOwnerUtc']
  stale_ids.append(item.get('id'))
  changed += 1

if changed:
  data['lastUpdatedUtc'] = datetime.datetime.utcfromtimestamp(now).replace(microsecond=0).isoformat() + 'Z'

if dry:
  print(f"DRY_RUN: would demote {changed} ready_to_send -> awaiting_owner (threshold={threshold}s)")
  if stale_ids:
    print("ids:")
    for i in stale_ids:
      print(f"- {i}")
else:
  if changed:
    with open(ledger_path,'w',encoding='utf-8') as f:
      json.dump(data,f,indent=2)
      f.write('\n')
  print(f"demoted={changed} threshold={threshold}s")
  if stale_ids:
    print("ids:")
    for i in stale_ids:
      print(f"- {i}")
PY