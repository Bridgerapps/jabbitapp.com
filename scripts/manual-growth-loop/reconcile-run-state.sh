#!/usr/bin/env bash
set -euo pipefail

# reconcile-run-state.sh
# If the canonical counter advances without a corresponding record-run entry,
# patch the gap so audits/"last 5" are reliable.
#
# Safe: only touches local state files under data/status + data/logs.

ROOT="/home/jabbit/.openclaw/workspace"
COUNTER="$ROOT/data/status/manual-growth-loop-counter.json"
HIST="$ROOT/data/status/manual-growth-loop-history.json"
LATEST="$ROOT/data/status/manual-growth-loop-latest.json"
JSONL="$ROOT/data/logs/manual-growth-loop.jsonl"

mkdir -p "$(dirname "$COUNTER")" "$(dirname "$HIST")" "$(dirname "$LATEST")" "$(dirname "$JSONL")"

if [ ! -f "$COUNTER" ]; then
  echo '{"count":0}' > "$COUNTER"
fi
if [ ! -f "$HIST" ]; then
  echo '[]' > "$HIST"
fi
if [ ! -f "$JSONL" ]; then
  : > "$JSONL"
fi

count=$(jq -r '.count // 0' "$COUNTER" 2>/dev/null || echo 0)
last=$(jq -r 'if (type=="array" and length>0) then .[-1].iteration else 0 end' "$HIST" 2>/dev/null || echo 0)

if [ "$count" -le "$last" ]; then
  echo "ok: no gap (counter=$count history.last=$last)"
  exit 0
fi

ts=$(date -u +%FT%TZ)
COUNT="$count" LAST="$last" TS="$ts" node - <<'NODE'
const fs = require('fs');
const root = '/home/jabbit/.openclaw/workspace';
const histPath = `${root}/data/status/manual-growth-loop-history.json`;
const latestPath = `${root}/data/status/manual-growth-loop-latest.json`;
const jsonlPath = `${root}/data/logs/manual-growth-loop.jsonl`;
const driftPath = `${root}/data/status/manual-growth-loop-drift.json`;

const count = Number(process.env.COUNT||0);
const last = Number(process.env.LAST||0);
const ts = process.env.TS;

let hist;
try { hist = JSON.parse(fs.readFileSync(histPath,'utf8')); } catch { hist = []; }

let appended = 0;
for (let i = last + 1; i <= count; i++) {
  const mode = (i % 5 === 0) ? 'self-improvement' : 'growth';
  const entry = {
    ts,
    iteration: i,
    mode,
    tags: ['R'],
    note: 'reconciled: missing record-run entry (counter advanced without history)'
  };
  hist.push(entry);
  fs.appendFileSync(jsonlPath, JSON.stringify(entry) + '\n');
  appended++;
}

// keep last 200 entries
if (hist.length > 200) hist = hist.slice(hist.length - 200);
fs.writeFileSync(histPath, JSON.stringify(hist, null, 2) + '\n');

const latest = { ts, iteration: count, mode: (count % 5 === 0) ? 'self-improvement' : 'growth' };
fs.writeFileSync(latestPath, JSON.stringify(latest, null, 2) + '\n');

// Drift telemetry: how often we have to reconcile gaps.
let drift = { lastTs: null, reconciledEvents: 0, lastAppended: 0, lastFrom: 0, lastTo: 0 };
try { drift = JSON.parse(fs.readFileSync(driftPath,'utf8')); } catch {}
drift.lastTs = ts;
drift.reconciledEvents = Number(drift.reconciledEvents||0) + 1;
drift.lastAppended = appended;
drift.lastFrom = last;
drift.lastTo = count;
fs.writeFileSync(driftPath, JSON.stringify(drift, null, 2) + '\n');

console.log(`ok: reconciled gap (history.last=${last} -> counter=${count}; appended=${appended})`);
NODE
