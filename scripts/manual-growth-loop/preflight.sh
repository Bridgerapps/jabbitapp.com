#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/jabbit/.openclaw/workspace"
WORKLOG="$ROOT/WORKLOG.md"
LEDGER="$ROOT/data/status/manual-growth-loop-ledger.json"
COUNTER="$ROOT/data/status/manual-growth-loop-counter.json"

need() {
  local f="$1"
  if [ ! -f "$f" ]; then
    echo "missing: $f" >&2
    return 1
  fi
}

need "$WORKLOG" || exit 1
need "$LEDGER" || exit 1

# Fail fast on missing deps (cron environments can differ).
"$ROOT/scripts/manual-growth-loop/deps-check.sh" >/tmp/manual-growth-loop-deps.txt 2>&1 || {
  cat /tmp/manual-growth-loop-deps.txt >&2 || true
  exit 2
}

# Read counter WITHOUT mutating it (cron/job runner owns increments).
iter=$(jq -r '.count // 0' "$COUNTER" 2>/dev/null || echo 0)
next=$((iter+1))
mode="growth"
if (( next % 5 == 0 )); then mode="self-improvement"; fi

ready=$(jq -r '[.sendQueues[] | select(.status=="ready_to_send")] | length' "$LEDGER")
draft=$(jq -r '[.sendQueues[] | select(.status=="draft_needed")] | length' "$LEDGER")

now=$(date -u +%FT%TZ)

echo "now: $now"
echo "counter.current: $iter"
echo "iteration.next: $next"
echo "mode: $mode"
echo "ledger: ready_to_send=$ready draft_needed=$draft"

# Hard guardrail: if ready_to_send is stagnant, do NOT generate more work.
# This prevents the loop from endlessly producing briefs/copy without state advancement.
if "$ROOT/scripts/manual-growth-loop/stagnation-check.sh" "$LEDGER" >/tmp/manual-growth-loop-stagnation.txt 2>&1; then
  true
else
  code=$?
  if [ "$code" -eq 10 ]; then
    cat /tmp/manual-growth-loop-stagnation.txt
    echo "STOP: stale ready_to_send queue — send + mark sent before creating new work"
    echo "hint: run $ROOT/scripts/manual-growth-loop/stale-ready-to-send-nudge.sh"
    echo "hint: if this has been stuck for days, generate a send-only escalation brief (rate-limited):"
    echo "      $ROOT/scripts/manual-growth-loop/maybe-escalate-stale-ready.sh"
    exit 33
  fi
  # Unknown error: surface it, but don't block the whole system.
  cat /tmp/manual-growth-loop-stagnation.txt >&2 || true
fi

# Second hard guardrail: block on *aged* ready_to_send items (not just streak).
# Rationale: a single run could miss the streak threshold, but anything >24h old must be acted on.
THRESHOLD_SECONDS="${THRESHOLD_SECONDS:-86400}"
"$ROOT/scripts/manual-growth-loop/stale-ready-report.sh" "$LEDGER" >/tmp/manual-growth-loop-stale-ready.txt 2>&1 || true
if ! grep -q "^STALE_READY_REPORT: none" /tmp/manual-growth-loop-stale-ready.txt; then
  cat /tmp/manual-growth-loop-stale-ready.txt
  echo "STOP: ready_to_send items are older than ${THRESHOLD_SECONDS}s — send/close + mark state before new work"
  exit 33
fi

# Non-zero exit to force self-improvement precedence (prevents accidental normal-task runs)
if [ "$mode" = "self-improvement" ]; then
  exit 22
fi
