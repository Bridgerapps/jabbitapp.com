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

    LAST_OUT="$ROOT/data/status/growth-default-actions-last.json"
    ran_m=0; ran_r=0; ran_l=0; ran_p=0; ran_n=0
    if [ -f "$LAST_OUT" ]; then
      ran_m=$(jq -r '.ran.measurement // false' "$LAST_OUT" 2>/dev/null | grep -qi true && echo 1 || echo 0)
      ran_r=$(jq -r '.ran.reddit // false' "$LAST_OUT" 2>/dev/null | grep -qi true && echo 1 || echo 0)
      ran_l=$(jq -r '.ran.packs // false' "$LAST_OUT" 2>/dev/null | grep -qi true && echo 1 || echo 0)
      ran_p=$(jq -r '.ran.owner_ping // false' "$LAST_OUT" 2>/dev/null | grep -qi true && echo 1 || echo 0)
      ran_n=$(jq -r '.ran.nextpack // false' "$LAST_OUT" 2>/dev/null | grep -qi true && echo 1 || echo 0)
    fi

    finish_tags=""
    [ "$ran_m" -eq 1 ] && finish_tags="${finish_tags}M,"
    [ "$ran_r" -eq 1 ] && finish_tags="${finish_tags}R,"
    [ "$ran_l" -eq 1 ] && finish_tags="${finish_tags}L,"
    [ "$ran_p" -eq 1 ] && finish_tags="${finish_tags}P,"
    [ "$ran_n" -eq 1 ] && finish_tags="${finish_tags}N,"
    finish_tags=${finish_tags%,}

    out_one=$(printf "%s" "$out" | tr '\n' ' ')
    out_one=${out_one:0:900}

    if [ -z "$finish_tags" ]; then
      # Keep the history note compact; detailed next-steps live in growth-default-actions-noop-next.txt
      next_at=""
      next_in=""
      if [ -f "$LAST_OUT" ]; then
        next_at=$(jq -r '.next_eligible_at_utc // empty' "$LAST_OUT" 2>/dev/null || true)
        next_in=$(jq -r '.next_eligible_in_seconds // empty' "$LAST_OUT" 2>/dev/null || true)
      fi

      extra=""
      [ -n "$next_at" ] && extra=" next_eligible_at_utc=$next_at"
      [ -n "$next_in" ] && extra="${extra} next_eligible_in_seconds=$next_in"

      bash "$ROOT/scripts/manual-growth-loop/record-finish.sh"         --note "FINISH: growth-default-actions NOOP (cooldowns). See data/status/growth-default-actions-noop-next.txt.${extra}"
    else
      bash "$ROOT/scripts/manual-growth-loop/record-finish.sh" \
        --tags "$finish_tags" \
        --note "FINISH: Ran growth-default-actions. Tags=[$finish_tags]. Output: $out_one"
    fi
  elif [ $code -eq 22 ]; then
    # Reliability: if it's a self-improvement iteration, actually run the harness
    # so the run isn't just a blank preflight log.
    bash "$ROOT/scripts/manual-growth-loop/self-improvement-run.sh" >/dev/null 2>&1 || true
  else
    bash "$ROOT/scripts/manual-growth-loop/auto-finish.sh" --preflight-code "$code" >/dev/null 2>&1 || true
  fi
fi

exit 0
