#!/usr/bin/env bash
set -euo pipefail

# cooldown-health.sh
# Purpose: quantify "cooldown-bound churn" and recommend a safer cron interval.
# Output: human-readable summary to stdout + JSON snapshot to data/status/.
# Safe: local-only.

ROOT="/home/jabbit/.openclaw/workspace"
STATE="$ROOT/data/status/growth-default-actions-state.json"
CHURN="$ROOT/data/status/manual-growth-loop-churn-latest.json"
NOOP_NEXT="$ROOT/data/status/growth-default-actions-noop-next.txt"
OUT="$ROOT/data/status/manual-growth-loop-cooldown-health.json"

now_utc=$(date -u +%FT%TZ)
now_s=$(date -u +%s)

if [ ! -s "$STATE" ]; then
  echo "missing state: $STATE" >&2
  exit 2
fi

# Cooldowns mirror growth-default-actions.sh (seconds)
COOLDOWN_MEASUREMENT=$((60*60))
COOLDOWN_REDDIT=$((2*60*60))
COOLDOWN_PACKS=$((24*60*60))
COOLDOWN_OWNER_PING=$((60*60))
COOLDOWN_NEXTPACK=$((15*60))
COOLDOWN_GRACE_SECONDS=90

last_epoch() {
  local key="$1"
  local v
  v=$(jq -r --arg k "$key" '.[$k] // empty' "$STATE" 2>/dev/null || true)
  if [ -z "$v" ] || [ "$v" = "null" ]; then echo 0; else echo "$v"; fi
}

remaining_seconds() {
  local key="$1"
  local cooldown="$2"
  local last
  last=$(last_epoch "$key")
  if [ "$last" -eq 0 ]; then echo 0; return; fi
  local age=$((now_s - last))

  local effective=$cooldown
  if [ "$effective" -gt "$COOLDOWN_GRACE_SECONDS" ]; then
    effective=$((effective - COOLDOWN_GRACE_SECONDS))
  else
    effective=0
  fi

  if [ "$age" -ge "$effective" ]; then
    echo 0
  else
    echo $(( effective - age ))
  fi
}

# Remaining cooldown seconds for each lane (0 = eligible)
rem_measure=$(remaining_seconds "measurement" "$COOLDOWN_MEASUREMENT")
rem_reddit=$(remaining_seconds "reddit" "$COOLDOWN_REDDIT")
rem_packs=$(remaining_seconds "packs" "$COOLDOWN_PACKS")
rem_owner=$(remaining_seconds "owner_ping" "$COOLDOWN_OWNER_PING")
rem_nextpack=$(remaining_seconds "nextpack" "$COOLDOWN_NEXTPACK")

min_rem=$rem_measure
for v in "$rem_reddit" "$rem_packs" "$rem_owner" "$rem_nextpack"; do
  if [ "$v" -lt "$min_rem" ]; then min_rem=$v; fi
done

# Heuristic recommendation:
# - If *everything* is in cooldown for >30m, hourly cron wastes cycles.
# - If we repeatedly run with only 1 cheap lane eligible (e.g., just measurement/owner_ping),
#   it's still churn. So also look at how many lanes are blocked for >=1h.
rec="hourly"
blocked_ge_1h=0
for v in "$rem_measure" "$rem_reddit" "$rem_packs" "$rem_owner" "$rem_nextpack"; do
  if [ "$v" -ge 3600 ]; then blocked_ge_1h=$((blocked_ge_1h+1)); fi
done

if [ "$min_rem" -ge 10800 ] || [ "$blocked_ge_1h" -ge 4 ]; then
  rec="every-4h"
elif [ "$min_rem" -ge 3600 ] || [ "$blocked_ge_1h" -ge 3 ]; then
  rec="every-2h"
elif [ "$min_rem" -ge 1800 ] || [ "$blocked_ge_1h" -ge 2 ]; then
  rec="every-90m"
fi

cooldown_bound_runs="unknown"
if [ -s "$CHURN" ]; then
  cooldown_bound_runs=$(jq -r '.counts.cooldown_bound // "unknown"' "$CHURN" 2>/dev/null || echo "unknown")
fi

noop_next_at=""
noop_next_in=""
if [ -f "$NOOP_NEXT" ]; then
  noop_next_in=$(grep -E '^next_eligible_in_seconds:' "$NOOP_NEXT" | awk '{print $2}' | tail -n 1 || true)
  noop_next_at=$(grep -E '^next_eligible_at_utc:' "$NOOP_NEXT" | awk '{print $2}' | tail -n 1 || true)
fi

cat >"$OUT" <<JSON
{
  "ts_utc": "${now_utc}",
  "cooldowns_remaining_sec": {
    "measurement": ${rem_measure},
    "reddit": ${rem_reddit},
    "packs": ${rem_packs},
    "owner_ping": ${rem_owner},
    "nextpack": ${rem_nextpack}
  },
  "min_remaining_sec": ${min_rem},
  "recent_cooldown_bound_runs": "${cooldown_bound_runs}",
  "noop_next": {
    "next_eligible_in_seconds": "${noop_next_in}",
    "next_eligible_at_utc": "${noop_next_at}"
  },
  "recommended_cron_interval": "${rec}"
}
JSON

# Human-readable
printf -- "cooldown-health @ %s\n" "$now_utc"
printf -- "- remaining_sec: measurement=%s reddit=%s packs=%s owner_ping=%s nextpack=%s (min=%s)\n" \
  "$rem_measure" "$rem_reddit" "$rem_packs" "$rem_owner" "$rem_nextpack" "$min_rem"
printf -- "- recent cooldown_bound runs (last 24 iters): %s\n" "$cooldown_bound_runs"
# Extra hint: if >50% of recent runs were cooldown-bound, the cron is mostly spinning.
if [[ "$cooldown_bound_runs" =~ ^[0-9]+$ ]] && [ "$cooldown_bound_runs" -ge 12 ]; then
  printf -- "- recommendation: reduce cooldowns or add a cheap always-eligible lane; >50%% of recent runs were cooldown-bound\n"
fi
printf -- "- recommended cron interval: %s\n" "$rec"
printf -- "- wrote: %s\n" "${OUT##$ROOT/}"
