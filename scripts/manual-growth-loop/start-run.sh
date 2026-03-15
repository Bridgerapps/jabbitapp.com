#!/usr/bin/env bash
set -euo pipefail

# start-run.sh
# - increments the canonical counter
# - computes mode (growth|self-improvement)
# - writes a small latest-run pointer
# - optionally records a run entry (with a note) for auditability
#
# Usage:
#   start-run.sh [--note "..."] [--tags "M,D,R"]

ROOT="/home/jabbit/.openclaw/workspace"
COUNTER="$ROOT/data/status/manual-growth-loop-counter.json"
LATEST="$ROOT/data/status/manual-growth-loop-latest.json"

note=""
tags=""

while [ $# -gt 0 ]; do
  case "$1" in
    --note) note="$2"; shift 2;;
    --tags) tags="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

iteration=$(bash "$ROOT/scripts/manual-growth-loop/increment-counter.sh" "$COUNTER")

mode="growth"
if [ $((iteration % 5)) -eq 0 ]; then
  mode="self-improvement"
fi

ts=$(date -u +%FT%TZ)
mkdir -p "$(dirname "$LATEST")"
TS="$ts" ITER="$iteration" MODE="$mode" node - <<'NODE'
const fs = require('fs');
const p = '/home/jabbit/.openclaw/workspace/data/status/manual-growth-loop-latest.json';
const entry = { ts: process.env.TS, iteration: Number(process.env.ITER), mode: process.env.MODE };
fs.writeFileSync(p, JSON.stringify(entry, null, 2) + '\n');
console.log(`ok: latest -> ${p}`);
NODE

# Record the run for audit trails (even if note is empty).
# Tags are optional; keep them short and meaningful (M=measurement, D=distribution, R=reliability).
bash "$ROOT/scripts/manual-growth-loop/record-run.sh" \
  --iteration "$iteration" \
  --mode "$mode" \
  ${tags:+--tags "$tags"} \
  ${note:+--note "$note"}

echo "iteration=${iteration} mode=${mode}"
