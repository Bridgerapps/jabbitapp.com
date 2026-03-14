#!/usr/bin/env bash
set -euo pipefail

# Append a lightweight record to manual-growth-loop-history.json
# Usage:
#   record-run.sh --iteration 45 --mode growth --tags "M,D" --note "did X"

ROOT="/home/jabbit/.openclaw/workspace"
HIST="$ROOT/data/status/manual-growth-loop-history.json"
JSONL="$ROOT/data/logs/manual-growth-loop.jsonl"

iteration=""
mode=""
tags_csv=""
note=""

while [ $# -gt 0 ]; do
  case "$1" in
    --iteration) iteration="$2"; shift 2;;
    --mode) mode="$2"; shift 2;;
    --tags) tags_csv="$2"; shift 2;;
    --note) note="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

if [ -z "$iteration" ] || [ -z "$mode" ]; then
  echo "--iteration and --mode are required" >&2
  exit 2
fi

mkdir -p "$(dirname "$HIST")" "$(dirname "$JSONL")"
if [ ! -f "$HIST" ]; then
  echo '[]' > "$HIST"
fi
if [ ! -f "$JSONL" ]; then
  : > "$JSONL"
fi

ts=$(date -u +%FT%TZ)

TAGS_JSON='[]'
if [ -n "$tags_csv" ]; then
  # split CSV to JSON array
  TAGS_JSON=$(TAGS="$tags_csv" node - <<'NODE'
const csv = process.env.TAGS || '';
const arr = csv.split(',').map(s=>s.trim()).filter(Boolean);
process.stdout.write(JSON.stringify(arr));
NODE
  )
fi

HIST="$HIST" JSONL="$JSONL" TS="$ts" ITER="$iteration" MODE="$mode" NOTE="$note" TAGS_JSON="$TAGS_JSON" node - <<'NODE'
const fs = require('fs');
const histPath = process.env.HIST;
const jsonlPath = process.env.JSONL;
const ts = process.env.TS;
const iteration = Number(process.env.ITER);
const mode = process.env.MODE;
const note = process.env.NOTE || '';
const tags = JSON.parse(process.env.TAGS_JSON || '[]');

const entry = { ts, iteration, mode, tags, note };

let arr;
try { arr = JSON.parse(fs.readFileSync(histPath,'utf8')); } catch { arr = []; }
arr.push(entry);
// keep last 200 entries to avoid unbounded growth
if (arr.length > 200) arr = arr.slice(arr.length - 200);
fs.writeFileSync(histPath, JSON.stringify(arr, null, 2) + '\n');

// Also append to JSONL for easy tail/grep in ops.
fs.appendFileSync(jsonlPath, JSON.stringify(entry) + '\n');

console.log(`ok: recorded (history_n=${arr.length})`);
NODE
