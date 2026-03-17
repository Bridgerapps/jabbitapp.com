#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/jabbit/.openclaw/workspace"
HISTORY="$ROOT/data/status/manual-growth-loop-history.json"
LEDGER="$ROOT/data/status/manual-growth-loop-ledger.json"
COUNTER="$ROOT/data/status/manual-growth-loop-counter.json"

need() {
  local f="$1"
  if [ ! -f "$f" ]; then
    echo "missing: $f" >&2
    return 1
  fi
}

if [ ! -f "$HISTORY" ]; then
  mkdir -p "$(dirname "$HISTORY")"
  echo '[]' > "$HISTORY"
fi
need "$LEDGER" || exit 1

# Fail fast on missing deps (cron environments can differ).
"$ROOT/scripts/manual-growth-loop/deps-check.sh" >/tmp/manual-growth-loop-deps.txt 2>&1 || {
  cat /tmp/manual-growth-loop-deps.txt >&2 || true
  exit 2
}

# Hard boundary: Jabbit outbound must never use Adprax sender/domain.
# (If someone reintroduces an automated sender later, this guard should catch it.)
"$ROOT/scripts/manual-growth-loop/guard-no-adprax-sender.sh" || exit $?

# Reconcile state drift (counter can advance without record-run entries).
# This keeps audits reliable even if a run increments the counter manually.
"$ROOT/scripts/manual-growth-loop/reconcile-run-state.sh" >/tmp/manual-growth-loop-reconcile.txt 2>&1 || true

# Read counter WITHOUT mutating it (cron/job runner owns increments).
iter=$(jq -r '.count // 0' "$COUNTER" 2>/dev/null || echo 0)
next=$((iter+1))
mode="growth"
if (( next % 5 == 0 )); then mode="self-improvement"; fi

# Before doing any STOP checks, auto-demote stale ready_to_send items.
# This prevents endless "STOP" loops when the owner isn't in a send window.
# Default threshold aligns with stale-ready-report (24h) but can be overridden.
"$ROOT/scripts/manual-growth-loop/auto-demote-stale-ready.sh" "$LEDGER" >/tmp/manual-growth-loop-auto-demote.txt 2>&1 || true

ready=$(jq -r '[.sendQueues[] | select(.status=="ready_to_send")] | length' "$LEDGER")
draft=$(jq -r '[.sendQueues[] | select(.status=="draft_needed")] | length' "$LEDGER")

now=$(date -u +%FT%TZ)

# Reliability hint: detect when the counter is advancing but run history isn't being recorded.
last_hist_iter=$(jq -r 'if (type=="array" and length>0) then .[-1].iteration else null end' "$HISTORY" 2>/dev/null || echo null)
if [ "$last_hist_iter" != "null" ]; then
  gap=$(( iter - last_hist_iter ))
  if [ "$gap" -ge 2 ]; then
    echo "WARN: counter is ahead of recorded history (counter.current=$iter, history.last=$last_hist_iter, gap=$gap)."
    echo "      Fix: use scripts/manual-growth-loop/start-run.sh (preferred) or record-run.sh every run."
  fi
fi

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
    echo
    # Reduce decision load: print the actual nudge payload inline.
    # (Safe: no external sends; only prints suggestions + updates local nudge state.)
    FORCE=1 "$ROOT/scripts/manual-growth-loop/stale-ready-to-send-nudge.sh" || true
    echo
    # Reduce back-and-forth: generate a single owner-facing ping (rate-limited) with preflight + mark-sent cmds.
    "$ROOT/scripts/manual-growth-loop/maybe-generate-owner-send-ping.sh" || true
    echo "owner ping: $ROOT/data/status/owner-send-ping-latest.txt"
    echo
    echo "hint: generate a send-only escalation brief (rate-limited):"
    echo "      $ROOT/scripts/manual-growth-loop/maybe-escalate-stale-ready.sh"
    echo
    # If nudges are repeating, create/refresh an escalation brief sooner (12h) to reduce stall time.
    # This is still non-sending and rate-limited, but it gives the owner a clean, current send burst.
    # (Uses the nudge state JSON written by stale-ready-to-send-nudge.sh.)
    NUDGE_STATE="$ROOT/data/status/manual-growth-loop-nudge.json"
    if [ -f "$NUDGE_STATE" ]; then
      unchanged=$(jq -r '.unchangedNudges // 0' "$NUDGE_STATE" 2>/dev/null || echo 0)
      if [ "$unchanged" -ge 10 ]; then
        THRESHOLD_SEC=43200 MIN_INTERVAL_SECONDS=21600 "$ROOT/scripts/manual-growth-loop/maybe-escalate-stale-ready.sh" || true
      fi
    fi
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
  echo
  FORCE=1 "$ROOT/scripts/manual-growth-loop/stale-ready-to-send-nudge.sh" || true
  "$ROOT/scripts/manual-growth-loop/maybe-generate-owner-send-ping.sh" || true
  echo "owner ping: $ROOT/data/status/owner-send-ping-latest.txt"
  exit 33
fi

# Non-zero exit to force self-improvement precedence (prevents accidental normal-task runs)
if [ "$mode" = "self-improvement" ]; then
  exit 22
fi
