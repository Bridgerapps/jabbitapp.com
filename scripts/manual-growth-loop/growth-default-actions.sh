#!/usr/bin/env bash
set -euo pipefail

# growth-default-actions.sh
#
# Purpose: when preflight is OK (and we're not blocked on sends), run a small,
# repeatable set of *safe* growth actions that produce fresh opportunity/measurement
# state without doing any external authenticated posting/sending.
#
# This exists to prevent "growth" iterations from degenerating into no-op runs
# (counter advances; history records "preflight ok"; nothing actually changes).
#
# Guardrails:
# - NO automated posting/sending.
# - Prefer writing ephemeral outputs to data/status/*.json (or JSONL), not WORKLOG/docs.
# - Keep it to <=3 actions.
# - Avoid repetitive churn: each action has a cooldown window.

ROOT="/home/jabbit/.openclaw/workspace"
STATE="$ROOT/data/status/growth-default-actions-state.json"

# Cooldowns (seconds). Goal: reduce hourly repetition + artifact churn.
COOLDOWN_MEASUREMENT=$((6*60*60))  # 6h
COOLDOWN_REDDIT=$((6*60*60))       # 6h
COOLDOWN_PACKS=$((24*60*60))       # 24h

now_epoch=$(date -u +%s)

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
  tmp=$(mktemp)
  jq --arg k "$key" --argjson v "$now_epoch" '.[$k]=$v' "$STATE" >"$tmp"
  mv "$tmp" "$STATE"
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
  exit "$code"
fi

init_state

ran_any=0

# Action 1) Measurement snapshot (keeps KPI dashboard honest downstream)
# Writes: data/status/site-analytics.json
if should_run "measurement" "$COOLDOWN_MEASUREMENT"; then
  timeout 45s bash "$ROOT/scripts/site-analytics-status.sh" >/dev/null || true
  mark_ran "measurement"
  ran_any=1
else
  echo "growth-default-actions: skip measurement (cooldown)" >&2
fi

# Action 2) Reddit opportunity scouting (manual-only execution later)
# Writes: data/status/reddit-opps-*.json + reddit-opps-latest.json
if should_run "reddit" "$COOLDOWN_REDDIT"; then
  REDDIT_DISCOVERY_USE_COOKIE=false REDDIT_DISCOVERY_COOKIE_FALLBACK=false \
    timeout 45s python3 "$ROOT/scripts/reddit_smart_review_post.py" >/dev/null 2>&1 || true
  mark_ran "reddit"
  ran_any=1
else
  echo "growth-default-actions: skip reddit opps (cooldown)" >&2
fi

# Action 3) Refresh distribution packs (copy/paste snippets; no posting)
# Writes: output/distribution-pack-*.md
if should_run "packs" "$COOLDOWN_PACKS"; then
  timeout 45s bash "$ROOT/scripts/generate-distribution-packs.sh" >/dev/null || true
  mark_ran "packs"
  ran_any=1
else
  echo "growth-default-actions: skip distribution packs (cooldown)" >&2
fi

if [ "$ran_any" -eq 0 ]; then
  echo "growth-default-actions: NOOP (all actions in cooldown windows)" >&2
else
  echo "growth-default-actions: OK (ran at least 1 action; cooldowns active)"
fi
