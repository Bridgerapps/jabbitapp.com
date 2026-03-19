#!/usr/bin/env bash
set -euo pipefail

# run.sh — canonical entrypoint for manual-growth-loop runs.
# - increments counter + records run (via start-run.sh)
# - prints the computed iteration/mode
# - runs preflight for guardrails + ledger summary context
#
# Usage:
#   scripts/manual-growth-loop/run.sh [--note "..."] [--tags "M,D,R"]

ROOT="/home/jabbit/.openclaw/workspace"

note=""
tags=""

while [ $# -gt 0 ]; do
  case "$1" in
    --note) note="$2"; shift 2;;
    --tags) tags="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

out=$(bash "$ROOT/scripts/manual-growth-loop/start-run.sh" \
  ${note:+--note "$note"} \
  ${tags:+--tags "$tags"}
)

# start-run prints an "iteration=.. mode=.." line — surface it cleanly.
echo "$out" | tail -n 2

echo "--- preflight (guardrails; non-mutating) ---"
# preflight exits non-zero for self-improvement mode; that's expected.
set +e
bash "$ROOT/scripts/manual-growth-loop/preflight.sh"
code=$?
set -e

if [ $code -eq 22 ]; then
  echo "preflight: self-improvement mode (expected)"
elif [ $code -eq 33 ]; then
  echo "preflight: STOP (stagnation/aged ready_to_send)"
else
  echo "preflight: ok (code=$code)"
fi

# Reliability upgrade: cron-driven runs often start with an empty note.
# If preflight is OK, run a safe default action set so growth iterations actually advance state.
# Otherwise, auto-append a FINISH record summarizing the preflight outcome so audits don't go blank.
if [ -z "$note" ]; then
  if [ $code -eq 0 ]; then
    # Safe, non-authenticated, non-sending actions only.
    out=$(bash "$ROOT/scripts/manual-growth-loop/growth-default-actions.sh" 2>&1 || true)
    out_one=$(printf "%s" "$out" | tr '\n' ' ')
    # keep history notes short + readable
    out_one=${out_one:0:900}
    bash "$ROOT/scripts/manual-growth-loop/record-finish.sh" \
      --tags "M,R,L" \
      --note "Ran growth-default-actions (measurement + reddit opps + distribution check). Output: $out_one"
  else
    bash "$ROOT/scripts/manual-growth-loop/auto-finish.sh" --preflight-code "$code" >/dev/null 2>&1 || true
  fi
fi

exit 0
