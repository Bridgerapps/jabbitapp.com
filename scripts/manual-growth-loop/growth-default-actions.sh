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
# - Keep it to <=3 actions (soft cap; prefer 1-3).
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
COOLDOWN_MEASUREMENT=$((2*60*60))  # 2h (avoid long NOOP streaks)
COOLDOWN_REDDIT=$((2*60*60))       # 2h (avoid long NOOP streaks)
COOLDOWN_PACKS=$((24*60*60))       # 24h
COOLDOWN_OWNER_PING=$((2*60*60))   # 2h (owner backlog can be large)

now_epoch=$(date -u +%s)
now_iso=$(date -u +%FT%TZ)

init_state() {
  if [ ! -f "$STATE" ]; then
    mkdir -p "$(dirname "$STATE")"
    printf '{"measurement":null,"reddit":null,"packs":null,"owner_ping":null}\n' >"$STATE"
    return
  fi

  # Back-compat: older state files may miss keys.
  if ! jq -e '.owner_ping? // empty' "$STATE" >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq '. + {owner_ping:(.owner_ping // null)}' "$STATE" >"$tmp"
    mv "$tmp" "$STATE"
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
  # Usage: write_last_out <ran_measure> <ran_reddit> <ran_packs> <ran_owner_ping> <noop_reason> [next_eligible_in_seconds] [next_eligible_at_utc]
  local ran_measure="$1"
  local ran_reddit="$2"
  local ran_packs="$3"
  local ran_owner_ping="$4"
  local noop_reason="$5"
  local next_in="${6:-}"
  local next_at="${7:-}"

  mkdir -p "$(dirname "$LAST_OUT")"
  jq -n \
    --arg ts_utc "$now_iso" \
    --argjson measurement "$ran_measure" \
    --argjson reddit "$ran_reddit" \
    --argjson packs "$ran_packs" \
    --argjson owner_ping "$ran_owner_ping" \
    --arg noop_reason "$noop_reason" \
    --arg noop_next_file "$NOOP_NEXT_FILE" \
    --arg next_eligible_in_seconds "${next_in}" \
    --arg next_eligible_at_utc "${next_at}" \
    '{
      ts_utc:$ts_utc,
      ran:{measurement:$measurement, reddit:$reddit, packs:$packs, owner_ping:$owner_ping},
      noop_reason:($noop_reason|select(length>0)),
      noop_next_file:$noop_next_file,
      next_eligible_in_seconds:(($next_eligible_in_seconds|select(length>0))|tonumber?),
      next_eligible_at_utc:($next_eligible_at_utc|select(length>0))
    }' \
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
  write_last_out 0 0 0 0 "preflight_not_ok"
  exit "$code"
fi

init_state

ran_measure=0
ran_reddit=0
ran_packs=0
ran_owner_ping=0

# Action 1) Measurement snapshot (keeps KPI dashboard honest downstream)
# Writes: data/status/site-analytics.json
if should_run "measurement" "$COOLDOWN_MEASUREMENT"; then
  if timeout 45s bash "$ROOT/scripts/site-analytics-status.sh" >/dev/null; then
    mark_ran "measurement"
    ran_measure=1
  else
    echo "growth-default-actions: measurement command failed (will not start cooldown)" >&2
  fi
else
  echo "growth-default-actions: skip measurement (cooldown)" >&2
fi

# Action 2) Reddit opportunity scouting (manual-only execution later)
# Writes: data/status/reddit-opps-*.json + reddit-opps-latest.json
if should_run "reddit" "$COOLDOWN_REDDIT"; then
  if REDDIT_DISCOVERY_USE_COOKIE=false REDDIT_DISCOVERY_COOKIE_FALLBACK=false \
    timeout 45s python3 "$ROOT/scripts/reddit_smart_review_post.py" >/dev/null 2>&1; then
    mark_ran "reddit"
    ran_reddit=1
  else
    echo "growth-default-actions: reddit scouting failed (will not start cooldown)" >&2
  fi
else
  echo "growth-default-actions: skip reddit opps (cooldown)" >&2
fi

# Action 3) Refresh distribution packs (copy/paste snippets; no posting)
# Writes: output/distribution-pack-*.md
if should_run "packs" "$COOLDOWN_PACKS"; then
  if timeout 45s bash "$ROOT/scripts/generate-distribution-packs.sh" >/dev/null; then
    mark_ran "packs"
    ran_packs=1
  else
    echo "growth-default-actions: distribution packs generation failed (will not start cooldown)" >&2
  fi
else
  echo "growth-default-actions: skip distribution packs (cooldown)" >&2
fi

# Action 4) When we have awaiting_owner backlog, refresh the owner ping pack.
# This is low-cost, doesn't require Brave, and makes the next manual step obvious.
# Writes: data/status/owner-send-ping-latest.txt
if should_run "owner_ping" "$COOLDOWN_OWNER_PING"; then
  # The script self-rate-limits; only start our cooldown if it actually refreshed.
  out_owner=$(timeout 30s bash "$ROOT/scripts/manual-growth-loop/maybe-generate-owner-send-ping.sh" 2>&1 || true)
  if echo "$out_owner" | grep -q "^OK:"; then
    mark_ran "owner_ping"
    ran_owner_ping=1
  else
    echo "growth-default-actions: owner ping not refreshed (fresh or failed)" >&2
  fi
else
  echo "growth-default-actions: skip owner ping (cooldown)" >&2
fi

ran_any=$((ran_measure + ran_reddit + ran_packs + ran_owner_ping))

remaining_seconds() {
  # Usage: remaining_seconds <key> <cooldown_seconds>
  # Returns 0 if eligible now; otherwise positive seconds remaining.
  local key="$1"
  local cooldown="$2"
  local last
  last=$(last_epoch "$key")
  if [ "$last" -eq 0 ]; then
    echo 0
    return
  fi
  local age=$((now_epoch - last))
  if [ "$age" -ge "$cooldown" ]; then
    echo 0
  else
    echo $((cooldown - age))
  fi
}

next_eligible_in() {
  # Minimum remaining seconds across actions (0 means something eligible now).
  local r
  local min=999999999
  for spec in \
    "measurement:$COOLDOWN_MEASUREMENT" \
    "reddit:$COOLDOWN_REDDIT" \
    "packs:$COOLDOWN_PACKS" \
    "owner_ping:$COOLDOWN_OWNER_PING"; do
    local key=${spec%%:*}
    local cd=${spec##*:}
    r=$(remaining_seconds "$key" "$cd")
    if [ "$r" -lt "$min" ]; then
      min="$r"
    fi
  done
  if [ "$min" -eq 999999999 ]; then
    echo 0
  else
    echo "$min"
  fi
}

if [ "$ran_any" -eq 0 ]; then
  echo "growth-default-actions: NOOP (all actions in cooldown windows)" >&2

  # Avoid rewriting the same NOOP guidance every hour (reduces churn + makes audits cleaner).
  tmp_noop=$(mktemp)
  next_in=$(next_eligible_in)
  next_at="$(date -u -d "@$((now_epoch + next_in))" +%FT%TZ 2>/dev/null || true)"

  {
    echo "ts_utc: $now_iso"
    echo "reason: all default actions in cooldown windows"
    echo "next_eligible_in_seconds: $next_in"
    [ -n "$next_at" ] && echo "next_eligible_at_utc: $next_at"
    echo
    echo "--- operator-next ---"
    bash "$ROOT/scripts/manual-growth-loop/operator-next.sh" 2>/dev/null || true
    echo
    echo "--- ledger-next ---"
    bash "$ROOT/scripts/manual-growth-loop/ledger-next.sh" 2>/dev/null || true
  } >"$tmp_noop" 2>/dev/null || true

  if [ -f "$NOOP_NEXT_FILE" ] && sha256sum "$NOOP_NEXT_FILE" "$tmp_noop" >/dev/null 2>&1; then
    # sha256sum returns non-zero on diff; but doesn't print in this mode.
    :
  fi

  if [ ! -f "$NOOP_NEXT_FILE" ] || ! cmp -s "$NOOP_NEXT_FILE" "$tmp_noop"; then
    mv "$tmp_noop" "$NOOP_NEXT_FILE"
    echo "growth-default-actions: wrote noop next step -> $NOOP_NEXT_FILE" >&2
  else
    rm -f "$tmp_noop"
    echo "growth-default-actions: noop next unchanged (not rewriting)" >&2
  fi

  write_last_out 0 0 0 0 "all_in_cooldown" "$next_in" "$next_at"
else
  write_last_out "$ran_measure" "$ran_reddit" "$ran_packs" "$ran_owner_ping" ""
  echo "growth-default-actions: OK (ran at least 1 action; cooldowns active)"
fi
