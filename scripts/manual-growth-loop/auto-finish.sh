#!/usr/bin/env bash
set -euo pipefail

# auto-finish.sh
# Append a FINISH record for the most recent run with an auto-generated note.
# Goal: prevent empty notes in JSONL, improving audit reliability for cron-driven runs.
# Safe: only writes to local run history JSONL via record-finish.sh.
#
# Usage:
#   scripts/manual-growth-loop/auto-finish.sh --preflight-code 33

ROOT="/home/jabbit/.openclaw/workspace"
LATEST="$ROOT/data/status/manual-growth-loop-latest.json"
LEDGER="$ROOT/data/status/manual-growth-loop-ledger.json"
STAG="$ROOT/data/status/manual-growth-loop-stagnation.json"
NUDGE="$ROOT/data/status/manual-growth-loop-nudge.json"

code=""
while [ $# -gt 0 ]; do
  case "$1" in
    --preflight-code) code="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

if [ -z "$code" ]; then
  echo "--preflight-code is required" >&2
  exit 2
fi

if [ ! -f "$LATEST" ]; then
  echo "missing latest pointer: $LATEST" >&2
  exit 2
fi

iteration=$(jq -r '.iteration' "$LATEST")
mode=$(jq -r '.mode' "$LATEST")

ready="?"
oldest="?"
if [ -f "$LEDGER" ]; then
  ready=$(jq -r '[.sendQueues[] | select(.status=="ready_to_send")] | length' "$LEDGER" 2>/dev/null || echo "?")
  oldest=$(jq -r '[.sendQueues[] | select(.status=="ready_to_send") | .whenUtc] | map(select(.!=null)) | sort | .[0] // "?"' "$LEDGER" 2>/dev/null || echo "?")
fi

streak="?"
unchanged="?"
if [ -f "$STAG" ]; then
  streak=$(jq -r '.streak // "?"' "$STAG" 2>/dev/null || echo "?")
fi
if [ -f "$NUDGE" ]; then
  unchanged=$(jq -r '.unchangedNudges // "?"' "$NUDGE" 2>/dev/null || echo "?")
fi

case "$code" in
  33)
    note="Preflight STOP (stale ready_to_send=${ready}, oldest=${oldest}, streak=${streak}, unchangedNudges=${unchanged}). Next: manual send top items + mark sent/closed in ledger."
    tags="R"
    ;;
  22)
    note="Preflight indicates self-improvement mode. Next: audit last 5 runs + apply 1 process upgrade."
    tags="R"
    ;;
  *)
    note="Preflight completed (code=${code}). ready_to_send=${ready} (oldest=${oldest})."
    tags="R"
    ;;
esac

# Avoid double-finishing if a FINISH record already exists for this iteration.
# (audit-last-5 de-dupes, but JSONL should still stay clean.)
if tail -n 200 "$ROOT/data/logs/manual-growth-loop.jsonl" 2>/dev/null | grep -q "\"iteration\":${iteration}.*FINISH:"; then
  exit 0
fi

bash "$ROOT/scripts/manual-growth-loop/record-finish.sh" --note "$note" --tags "$tags"
