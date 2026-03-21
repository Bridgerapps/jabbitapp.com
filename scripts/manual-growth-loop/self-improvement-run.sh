#!/usr/bin/env bash
set -euo pipefail

# self-improvement-run.sh
# Purpose: make self-improvement iterations actually happen (repeatable + auditable).
# - runs the last-5 audit
# - actively applies safe local fixes (measurement/KPI/status/push-if-clean)
# - writes a small, timestamped report to data/status/
# - records a FINISH note indicating what changed
# Safe: local-only writes (data/status + run history). No external sends.

ROOT="/home/jabbit/.openclaw/workspace"
LATEST="$ROOT/data/status/manual-growth-loop-latest.json"
OUTDIR="$ROOT/data/status"

if [ ! -f "$LATEST" ]; then
  echo "missing latest pointer: $LATEST" >&2
  exit 2
fi

iteration=$(jq -r '.iteration' "$LATEST")
mode=$(jq -r '.mode' "$LATEST")

ts=$(date -u +%Y-%m-%dT%H%M%SZ)
report_txt="$OUTDIR/manual-growth-loop-self-improvement-${iteration}-${ts}.txt"
act_json="$OUTDIR/manual-growth-loop-act-on-issues-last.json"

# Crucial: self-improvement should change system state when it safely can.
bash "$ROOT/scripts/manual-growth-loop/act-on-issues.sh" >/dev/null 2>&1 || true

{
  echo "self-improvement-report"
  echo "ts_utc: $(date -u +%FT%TZ)"
  echo "iteration: ${iteration}"
  echo "mode: ${mode}"
  echo
  echo "## act-on-issues (safe local fixes applied first)"
  if [ -f "$act_json" ]; then
    cat "$act_json"
  else
    echo "missing: ${act_json}"
  fi
  echo
  echo "## audit-last-5"
  IGNORE_ITERATION="$iteration" bash "$ROOT/scripts/manual-growth-loop/audit-last-5.sh" || true
  echo
  echo "## operator-next (preflight-derived)"
  bash "$ROOT/scripts/manual-growth-loop/operator-next.sh" || true
  echo
  if [ -f "$ROOT/data/status/growth-default-actions-noop-next.txt" ]; then
    echo "## latest noop-next (if recent runs were cooldown NOOPs)"
    sed -n '1,200p' "$ROOT/data/status/growth-default-actions-noop-next.txt" || true
    echo
  fi
  echo "## recommended process upgrades (operator picks 1-3)"
  echo "- When mode=self-improvement, ALWAYS run this script, then record-finish with what changed."
  echo "- Prefer upgrades that reduce repeat loops: stronger STOP reasons, better next-action surfacing, fewer empty runs."
  echo "- Keep outputs ephemeral unless it changes system state: write to data/status or scripts/, not WORKLOG." 
} | tee "$report_txt" >/dev/null

# Record a finish note that this iteration executed the self-improvement harness.
# (If operator also applied other changes, they should record an additional finish note manually.)
ran_summary="unknown"
if [ -f "$act_json" ]; then
  ran_summary=$(jq -r '[.ran | to_entries[] | select(.value==true) | .key] | if length==0 then "none" else join(",") end' "$act_json" 2>/dev/null || echo "unknown")
fi

bash "$ROOT/scripts/manual-growth-loop/record-finish.sh" \
  --tags "R,P" \
  --note "SELF-IMPROVEMENT: ran self-improvement-run.sh, applied safe local fixes=[${ran_summary}], and wrote ${report_txt##$ROOT/}. Next: only escalate issues that truly require owner action." 

echo "wrote: $report_txt"
