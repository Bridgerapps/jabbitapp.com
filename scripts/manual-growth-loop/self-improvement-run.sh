#!/usr/bin/env bash
set -euo pipefail

# self-improvement-run.sh
# Purpose: make self-improvement iterations actually happen (repeatable + auditable).
# - runs the last-5 audit
# - writes a small, timestamped report to data/status/
# - records a FINISH note indicating the upgrade applied
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

{
  echo "self-improvement-report"
  echo "ts_utc: $(date -u +%FT%TZ)"
  echo "iteration: ${iteration}"
  echo "mode: ${mode}"
  echo
  echo "## audit-last-5"
  bash "$ROOT/scripts/manual-growth-loop/audit-last-5.sh" || true
  echo
  echo "## recommended process upgrades (operator picks 1-3)"
  echo "- When mode=self-improvement, ALWAYS run this script, then record-finish with what changed."
  echo "- Prefer upgrades that reduce repeat loops: stronger STOP reasons, better next-action surfacing, fewer empty runs."
  echo "- Keep outputs ephemeral unless it changes system state: write to data/status or scripts/, not WORKLOG." 
} | tee "$report_txt" >/dev/null

# Record a finish note that this iteration executed the self-improvement harness.
# (If operator also applied other changes, they should record an additional finish note manually.)
bash "$ROOT/scripts/manual-growth-loop/record-finish.sh" \
  --tags "R,P" \
  --note "SELF-IMPROVEMENT: ran self-improvement-run.sh and wrote ${report_txt##$ROOT/}. Next: apply 1 concrete upgrade (script/guardrail), verify, commit if changed." 

echo "wrote: $report_txt"
