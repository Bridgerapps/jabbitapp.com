#!/usr/bin/env bash
set -euo pipefail

# churn-report.sh
# Purpose: summarize recent run churn (cooldown-bound runs, tag distribution)
# and write a small JSON report to data/status/.
# Safe: local-only read/write.

ROOT="/home/jabbit/.openclaw/workspace"
HISTORY_JSONL="$ROOT/data/logs/manual-growth-loop.jsonl"
OUT_JSON="$ROOT/data/status/manual-growth-loop-churn-latest.json"
N_DISTINCT="${N_DISTINCT:-24}"

mkdir -p "$(dirname "$OUT_JSON")"

if [ ! -s "$HISTORY_JSONL" ]; then
  jq -n --arg ts "$(date -u +%FT%TZ)" '{ts_utc:$ts, error:"missing_history_jsonl"}' >"$OUT_JSON"
  cat "$OUT_JSON"
  exit 0
fi

HISTORY_JSONL="$HISTORY_JSONL" N_DISTINCT="$N_DISTINCT" OUT_JSON="$OUT_JSON" node - <<'NODE'
const fs = require('fs');
const p = process.env.HISTORY_JSONL;
const out = process.env.OUT_JSON;
const N = Number(process.env.N_DISTINCT || 24);

const lines = fs.readFileSync(p,'utf8').trim().split(/\n+/).filter(Boolean);
const events = [];
for (const ln of lines) {
  try { events.push(JSON.parse(ln)); } catch {}
}

// keep best record per iteration (prefer FINISH/note)
function score(e){
  let s=0;
  const note=(e.note||'').trim();
  const tags=Array.isArray(e.tags)?e.tags:[];
  if (tags.length) s+=1;
  if (note) s+=2;
  if (/\bFINISH\b/.test(note)) s+=2;
  return s;
}

const byIter=new Map();
for (const e of events){
  if (e.iteration==null) continue;
  const k=String(e.iteration);
  const prev=byIter.get(k);
  if (!prev) { byIter.set(k,e); continue; }
  const s1=score(prev), s2=score(e);
  if (s2>s1) byIter.set(k,e);
  else if (s2===s1 && String(e.ts||'').localeCompare(String(prev.ts||''))>0) byIter.set(k,e);
}

const uniq=[...byIter.values()].sort((a,b)=>String(a.ts||'').localeCompare(String(b.ts||''))).reverse();
const slice=uniq.slice(0,N);

const tagCounts={};
let noop=0;
let cooldownOnly=0;
let growth=0;
let selfImprove=0;

for (const e of slice){
  const tags=Array.isArray(e.tags)?e.tags:[];
  for (const t of tags) tagCounts[t]=(tagCounts[t]||0)+1;

  const note=(e.note||'');
  if (/NOOP \(cooldowns\)/.test(note) || /noop next/.test(note)) noop++;

  if (e.mode==='growth') growth++;
  if (e.mode==='self-improvement') selfImprove++;

  // heuristic: runs that did measurement+nextpack only (tags subset of {M,P,N} and no R/L)
  const set=new Set(tags);
  const hasRL=set.has('R')||set.has('L')||set.has('D');
  const hasMPN=set.has('M')||set.has('P')||set.has('N');
  if (!hasRL && hasMPN) cooldownOnly++;
}

const ts = new Date().toISOString().replace(/\.\d{3}Z$/,'Z');
const report={
  ts_utc: ts,
  distinct_iterations: slice.length,
  window: {N},
  counts: {growth, self_improvement: selfImprove, noop, cooldown_bound: cooldownOnly},
  tag_counts: tagCounts,
  most_recent: slice[0] ? {ts: slice[0].ts, iteration: slice[0].iteration, mode: slice[0].mode, tags: slice[0].tags||[], note: slice[0].note||''} : null,
};

fs.writeFileSync(out, JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
NODE