#!/usr/bin/env bash
set -euo pipefail

# Append a lightweight record to manual-growth-loop-history.json
# Usage:
#   record-run.sh --iteration 45 --mode growth --tags "M,D" --note "did X"

ROOT="/home/jabbit/.openclaw/workspace"
HIST="$ROOT/data/status/manual-growth-loop-history.json"

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

mkdir -p "$(dirname "$HIST")"
if [ ! -f "$HIST" ]; then
  echo '[]' > "$HIST"
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

HIST="$HIST" TS="$ts" ITER="$iteration" MODE="$mode" NOTE="$note" TAGS_JSON="$TAGS_JSON" node - <<'NODE'
const fs = require('fs');
const p = process.env.HIST;
const ts = process.env.TS;
const iteration = Number(process.env.ITER);
const mode = process.env.MODE;
const note = process.env.NOTE || '';
const tags = JSON.parse(process.env.TAGS_JSON || '[]');

let arr;
try { arr = JSON.parse(fs.readFileSync(p,'utf8')); } catch { arr = []; }
arr.push({ ts, iteration, mode, tags, note });
// keep last 200 entries to avoid unbounded growth
if (arr.length > 200) arr = arr.slice(arr.length - 200);
fs.writeFileSync(p, JSON.stringify(arr, null, 2) + '\n');
console.log(`ok: appended (n=${arr.length})`);
NODE
