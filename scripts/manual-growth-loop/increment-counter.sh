#!/usr/bin/env bash
set -euo pipefail

COUNTER="${1:-/home/jabbit/.openclaw/workspace/data/status/manual-growth-loop-counter.json}"
mkdir -p "$(dirname "$COUNTER")"

if [ ! -f "$COUNTER" ]; then
  echo '{"count":0}' > "$COUNTER"
fi

# Use node (available in this environment) instead of python.
COUNTER_PATH="$COUNTER" node - <<'NODE'
const fs = require('fs');
const p = process.env.COUNTER_PATH;
let data;
try { data = JSON.parse(fs.readFileSync(p,'utf8')); } catch { data = {count:0}; }
const next = (Number(data.count)||0) + 1;
data.count = next;
fs.writeFileSync(p, JSON.stringify(data,null,2)+'\n');
console.log(next);
NODE
