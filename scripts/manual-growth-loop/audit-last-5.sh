#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/jabbit/.openclaw/workspace"
WORKLOG="${1:-$ROOT/WORKLOG.md}"
LEDGER="${LEDGER:-$ROOT/data/status/manual-growth-loop-ledger.json}"
HISTORY_JSON="$ROOT/data/status/manual-growth-loop-history.json"
HISTORY_JSONL="$ROOT/data/logs/manual-growth-loop.jsonl"

print_last5() {
  # Prefer JSONL, but de-dupe by iteration so "start" and "finish" records don't crowd out distinct runs.
  if [ -s "$HISTORY_JSONL" ]; then
    echo "# Last 5 distinct iterations (from JSONL; most recent first)"
    HISTORY_JSONL="$HISTORY_JSONL" node - <<'NODE'
const fs = require('fs');
const p = process.env.HISTORY_JSONL;
const lines = fs.readFileSync(p,'utf8').trim().split(/\n+/).filter(Boolean);
const parsed = [];
for (const ln of lines) {
  try { parsed.push(JSON.parse(ln)); } catch {}
}

const ignoreIter = (process.env.IGNORE_ITERATION || '').trim();

// Keep only the best record per iteration (prefer FINISH/non-empty notes),
// and optionally ignore the current in-progress iteration.
function score(e) {
  let s = 0;
  const note = (e.note || '');
  const tags = Array.isArray(e.tags) ? e.tags : [];
  if (tags.length) s += 1;
  if (note.trim().length) s += 2;
  if (/\bFINISH\b/.test(note)) s += 2;
  if (/SELF-IMPROVEMENT:/.test(note)) s += 1;
  return s;
}

const byIter = new Map();
for (const e of parsed) {
  const k = String(e.iteration);
  if (ignoreIter && k === ignoreIter) continue;

  const prev = byIter.get(k);
  if (!prev) { byIter.set(k, e); continue; }

  const s1 = score(prev);
  const s2 = score(e);
  if (s2 > s1) { byIter.set(k, e); continue; }
  if (s2 < s1) continue;

  const ets = (e.ts || '');
  const pts = (prev.ts || '');
  if (ets.localeCompare(pts) > 0) byIter.set(k, e);
}

const uniq = [...byIter.values()].sort((a,b)=> (a.ts||'').localeCompare(b.ts||'')).reverse();
for (const e of uniq.slice(0,5)) console.log(JSON.stringify(e));
NODE
    return 0
  fi

  if [ -s "$HISTORY_JSON" ]; then
    echo "# Last 5 runs (from history.json; most recent first)"
    HISTORY_JSON="$HISTORY_JSON" node - <<'NODE'
const fs = require('fs');
const p = process.env.HISTORY_JSON;
let arr=[];
try{arr=JSON.parse(fs.readFileSync(p,'utf8'));}catch{}
arr = Array.isArray(arr) ? arr : [];
const last = arr.slice(Math.max(0, arr.length-5)).reverse();
for (const e of last) console.log(JSON.stringify(e));
NODE
    return 0
  fi

  if [ -f "$WORKLOG" ]; then
    echo "# Last 5 growth-loop lines (from WORKLOG; most recent first)"
    grep -E '— (Growth loop|Self-improvement loop):' "$WORKLOG" | tail -n 5 | tac
    return 0
  fi

  echo "# Last 5 runs: none (no JSONL/history and WORKLOG missing)" >&2
}

LAST5=$(print_last5)
echo "$LAST5"

echo

echo "# Quick repetition hints (keyword frequency in last 5)"
for k in "copy" "outreach" "podcast" "Reddit" "KPI" "measurement" "analytics" "lead" "brief" "ready_to_send" "UTM" "send"; do
  c=$(printf "%s\n" "$LAST5" | grep -i -c "$k" || true)
  if [ "$c" -gt 0 ]; then
    printf -- "- %s: %s\n" "$k" "$c"
  fi
done

echo

echo "# Self-improvement debt (did we actually do it?)"
# Heuristic: if a self-improvement run ends with the generic "Next: ...self-improvement" note,
# it likely means we *didn't* perform the audit/process upgrade.
si_n=$(printf "%s\n" "$LAST5" | grep -c '"mode":"self-improvement"' || true)
si_unfinished=$(printf "%s\n" "$LAST5" | grep -c 'Preflight indicates self-improvement mode' || true)
si_finished=$(printf "%s\n" "$LAST5" | grep -c 'SELF-IMPROVEMENT:' || true)
if [ "$si_n" -gt 0 ]; then
  echo "- self-improvement runs in last5: $si_n (finished=$si_finished unfinished=$si_unfinished)"
  if [ "$si_unfinished" -gt 0 ]; then
    echo "- fix: run scripts/manual-growth-loop/self-improvement-run.sh"
  fi
else
  echo "- none in last5"
fi

echo

echo "# Queue stagnation check (ledger)"
if [ -f "$LEDGER" ]; then
  now=$(date -u +%s)
  ready=$(jq -r '[.sendQueues[]? | select(.status=="ready_to_send")] | length' "$LEDGER")
  oldest=$(jq -r '
    def to_epoch:
      ( .whenUtc // "" )
      | if .=="" then null
        else (sub("\\.[0-9]+Z$";"Z") | fromdateiso8601)
        end;
    [.sendQueues[]? | select(.status=="ready_to_send") | to_epoch]
    | map(select(.!=null))
    | if length==0 then null else (min) end
  ' "$LEDGER")

  if [ "$oldest" != "null" ]; then
    age=$(( now - oldest ))
    printf -- "- ready_to_send: %s (oldest_age_sec=%s)\n" "$ready" "$age"
    if [ "$age" -ge 14400 ]; then
      echo "- hint: queue is stale; run scripts/manual-growth-loop/stale-ready-to-send-nudge.sh"
    fi
  else
    printf -- "- ready_to_send: %s\n" "$ready"
  fi
else
  echo "- ledger missing (skipped): $LEDGER"
fi

echo

echo "# Cooldown churn check (last5)"
# Heuristic: if most recent growth runs are just default-actions with cooldown skips,
# we should tighten the loop (either relax cooldowns, lower schedule frequency, or
# ensure a cheap always-eligible action exists).
cd_packs=$(printf "%s\n" "$LAST5" | grep -c 'skip distribution packs (cooldown)' || true)
cd_reddit=$(printf "%s\n" "$LAST5" | grep -c 'skip reddit opps (cooldown)' || true)
cd_measure=$(printf "%s\n" "$LAST5" | grep -c 'skip measurement (cooldown)' || true)

printf -- "- cooldown_skips: measurement=%s reddit=%s packs=%s\n" "$cd_measure" "$cd_reddit" "$cd_packs"

if [ -f "$ROOT/data/status/growth-default-actions-noop-next.txt" ]; then
  next_in=$(grep -E '^next_eligible_in_seconds:' "$ROOT/data/status/growth-default-actions-noop-next.txt" | awk '{print $2}' | tail -n 1 || true)
  next_at=$(grep -E '^next_eligible_at_utc:' "$ROOT/data/status/growth-default-actions-noop-next.txt" | awk '{print $2}' | tail -n 1 || true)
  if [ -n "$next_in" ] || [ -n "$next_at" ]; then
    echo "- next_eligible_hint: in_seconds=${next_in:-unknown} at_utc=${next_at:-unknown}"
  fi
fi

# Suggest a single concrete improvement when churn is high.
# Threshold: if >=3 of last5 mention cooldown skips for BOTH reddit and packs.
if [ "$cd_reddit" -ge 3 ] && [ "$cd_packs" -ge 3 ]; then
  echo "- hint: last5 are mostly cooldown-bound; consider (a) running this loop every 2h instead of hourly, or (b) making one low-cost action always eligible (e.g., owner_ping or nextpack) without rewriting artifacts unless changed."
fi
