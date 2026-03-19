#!/usr/bin/env bash
set -euo pipefail

# growth-default-actions.sh
#
# Purpose: when preflight is OK (and we're not blocked on sends), run a small,
# repeatable set of *safe* growth actions that produce fresh opportunity/measurement
# state without doing any external authenticated posting/sending.
#
# Guardrails:
# - NO automated posting/sending.
# - Prefer writing ephemeral outputs to data/status/*.json (or JSONL), not WORKLOG/docs.
# - Keep it to <=3 actions.
# - Avoid repetitive churn: each action has a cooldown window.
#
# Reliability:
# - Always writes a machine-readable summary to data/status/growth-default-actions-last.json
#   so the caller can record accurate tags (prevents "ran M/R/L" when we NOOP).

ROOT="/home/jabbit/.openclaw/workspace"
STATE="$ROOT/data/status/growth-default-actions-state.json"
LAST_OUT="$ROOT/data/status/growth-default-actions-last.json"
NOOP_NEXT_FILE="$ROOT/data/status/growth-default-actions-noop-next.txt"

# Cooldowns (seconds). Goal: reduce hourly repetition + artifact churn.
COOLDOWN_MEASUREMENT=$((6*60*60))  # 6h
COOLDOWN_REDDIT=$((6*60*60))       # 6h
COOLDOWN_PACKS=$((24*60*60))       # 24h

now_epoch=$(date -u +%s)
now_iso=$(date -u +%FT%TZ)

init_state() {
  if [ ! -f "$STATE" ]; then
    mkdir -p "$(dirname "$STATE")"
    printf '{"measurement":null,"reddit":null,"packs":null}\n' >"$STATE"
  fi
}

last_epoch() {
  # Usage: last_epoch <key>
  # Returns: integer epoch or 0 if null/missing.
  local key="$1"
  local v
  v=$(jq -r --arg k "$key" '.[$k] // empty' "$STATE" 2>/dev/null || true)
  if [ -z "$v" ] || [ "$v" = "null" ]; then
    echo 0
  else
    echo "$v"
  fi
}

should_run() {
  # Usage: should_run <key> <cooldown_seconds>
  local key="$1"
  local cooldown="$2"
  local last
  last=$(last_epoch "$key")
  if [ "$last" -eq 0 ]; then
    return 0
  fi
  local age=$((now_epoch - last))
  [ "$age" -ge "$cooldown" ]
}

mark_ran() {
  # Usage: mark_ran <key>
  local key="$1"
  local tmp
  tmp=$(mktemp)
  jq --arg k "$key" --argjson v "$now_epoch" '.[$k]=$v' "$STATE" >"$tmp"
  mv "$tmp" "$STATE"
}

write_last_out() {
  # Usage: write_last_out <ran_measure> <ran_reddit> <ran_packs> <noop_reason>
  local ran_measure="$1"
  local ran_reddit="$2"
  local ran_packs="$3"
  local noop_reason="$4"

  mkdir -p "$(dirname "$LAST_OUT")"
  jq -n \
    --arg ts_utc "$now_iso" \
    --argjson measurement "$ran_measure" \
    --argjson reddit "$ran_reddit" \
    --argjson packs "$ran_packs" \
    --arg noop_reason "$noop_reason" \
    --arg noop_next_file "$NOOP_NEXT_FILE" \
    '{ts_utc:$ts_utc, ran:{measurement:$measurement, reddit:$reddit, packs:$packs}, noop_reason:($noop_reason|select(length>0)), noop_next_file:$noop_next_file}' \
    >"$LAST_OUT"
}

# Ensure we're not in a STOP/self-improvement state.
set +e
"$ROOT/scripts/manual-growth-loop/preflight.sh" >/tmp/manual-growth-loop-preflight.txt 2>&1
code=$?
set -e

if [ "$code" -ne 0 ]; then
  echo "growth-default-actions: preflight not OK (exit=$code) — refusing to run." >&2
  echo "--- preflight output ---" >&2
  cat /tmp/manual-growth-loop-preflight.txt >&2 || true
  # still emit last_out so caller can tag accurately
  write_last_out 0 0 0 "preflight_not_ok"
  exit "$code"
fi

init_state

ran_measure=0
ran_reddit=0
ran_packs=0

# Action 1) Measurement snapshot (keeps KPI dashboard honest downstream)
# Writes: data/status/site-analytics.json
if should_run "measurement" "$COOLDOWN_MEASUREMENT"; then
  timeout 45s bash "$ROOT/scripts/site-analytics-status.sh" >/dev/null || true
  mark_ran "measurement"
  ran_measure=1
else
  echo "growth-default-actions: skip measurement (cooldown)" >&2
fi

# Action 2) Reddit opportunity scouting (manual-only execution later)
# Writes: data/status/reddit-opps-*.json + reddit-opps-latest.json
if should_run "reddit" "$COOLDOWN_REDDIT"; then
  REDDIT_DISCOVERY_USE_COOKIE=false REDDIT_DISCOVERY_COOKIE_FALLBACK=false \
    timeout 45s python3 "$ROOT/scripts/reddit_smart_review_post.py" >/dev/null 2>&1 || true
  mark_ran "reddit"
  ran_reddit=1
else
  echo "growth-default-actions: skip reddit opps (cooldown)" >&2
fi

# Action 3) Refresh distribution packs (copy/paste snippets; no posting)
# Writes: output/distribution-pack-*.md
if should_run "packs" "$COOLDOWN_PACKS"; then
  timeout 45s bash "$ROOT/scripts/generate-distribution-packs.sh" >/dev/null || true
  mark_ran "packs"
  ran_packs=1
else
  echo "growth-default-actions: skip distribution packs (cooldown)" >&2
fi

ran_any=$((ran_measure + ran_reddit + ran_packs))

if [ "$ran_any" -eq 0 ]; then
  echo "growth-default-actions: NOOP (all actions in cooldown windows)" >&2

  # Reliability: if we can't run any default actions, still surface the
  # single highest-leverage *manual* next step (without mutating tracked docs).
  {
    echo "ts_utc: $now_iso"
    echo "reason: all default actions in cooldown windows"
    echo
    echo "--- operator-next ---"
    bash "$ROOT/scripts/manual-growth-loop/operator-next.sh" 2>/dev/null || true
    echo
    echo "--- ledger-next ---"
    bash "$ROOT/scripts/manual-growth-loop/ledger-next.sh" 2>/dev/null || true
  } >"$NOOP_NEXT_FILE" 2>/dev/null || true

  write_last_out 0 0 0 "all_in_cooldown"

  echo "growth-default-actions: wrote noop next step -> $NOOP_NEXT_FILE" >&2
else
  write_last_out "$ran_measure" "$ran_reddit" "$ran_packs" ""
  echo "growth-default-actions: OK (ran at least 1 action; cooldowns active)"
fi
