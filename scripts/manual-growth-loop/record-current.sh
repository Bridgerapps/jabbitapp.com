#!/usr/bin/env bash
set -euo pipefail

# record-current.sh
# If the counter was advanced outside the canonical entrypoint (run.sh/start-run.sh),
# this script backfills latest/history for the CURRENT counter value without incrementing.
#
# Usage:
#   scripts/manual-growth-loop/record-current.sh [--tags "R"] [--note "..."]

ROOT="/home/jabbit/.openclaw/workspace"
COUNTER="$ROOT/data/status/manual-growth-loop-counter.json"
LATEST="$ROOT/data/status/manual-growth-loop-latest.json"
HIST="$ROOT/data/status/manual-growth-loop-history.json"

note=""
tags=""

while [ $# -gt 0 ]; do
  case "$1" in
    --note) note="$2"; shift 2;;
    --tags) tags="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

if [ ! -f "$COUNTER" ]; then
  echo "missing counter: $COUNTER" >&2
  exit 2
fi

iteration=$(jq -r '.count // 0' "$COUNTER")
if [ "$iteration" = "0" ]; then
  echo "counter is 0; nothing to record" >&2
  exit 0
fi

mode="growth"
if [ $((iteration % 5)) -eq 0 ]; then
  mode="self-improvement"
fi

ts=$(date -u +%FT%TZ)

# Update latest pointer (idempotent)
mkdir -p "$(dirname "$LATEST")"
TS="$ts" ITER="$iteration" MODE="$mode" node - <<'NODE'
const fs = require('fs');
const p = '/home/jabbit/.openclaw/workspace/data/status/manual-growth-loop-latest.json';
const entry = { ts: process.env.TS, iteration: Number(process.env.ITER), mode: process.env.MODE };
fs.writeFileSync(p, JSON.stringify(entry, null, 2) + '\n');
console.log(`ok: latest -> ${p}`);
NODE

# If history already has this iteration, do nothing.
if [ ! -f "$HIST" ]; then
  echo '[]' > "$HIST"
fi

HAS=$(ITER="$iteration" node - <<'NODE'
const fs = require('fs');
const p = '/home/jabbit/.openclaw/workspace/data/status/manual-growth-loop-history.json';
const iter = Number(process.env.ITER);
let arr=[];
try { arr = JSON.parse(fs.readFileSync(p,'utf8')); } catch {}
process.stdout.write(arr.some(e => Number(e.iteration)===iter) ? '1' : '0');
NODE
)

if [ "$HAS" = "1" ]; then
  echo "ok: history already contains iteration=${iteration}";
  exit 0
fi

bash "$ROOT/scripts/manual-growth-loop/record-run.sh" \
  --iteration "$iteration" \
  --mode "$mode" \
  ${tags:+--tags "$tags"} \
  ${note:+--note "$note"}

echo "ok: recorded current iteration=${iteration} mode=${mode}"
