#!/usr/bin/env bash
set -euo pipefail

# act-on-issues-rate-limited.sh
# Purpose: prevent self-improvement loops from re-running heavy local maintenance
# when nothing material has changed.
#
# Behavior:
# - Computes a lightweight fingerprint of current health + git sync + dirty state.
# - If fingerprint is unchanged and last full act-on-issues run was recent,
#   SKIP the heavy run and still write a valid OUT json (so audits remain consistent).
# - Otherwise, run the full act-on-issues.sh and update the fingerprint state.

ROOT="/home/jabbit/.openclaw/workspace"
OUT="$ROOT/data/status/manual-growth-loop-act-on-issues-last.json"
STATE="$ROOT/data/status/manual-growth-loop-act-on-issues-state.json"
HEALTH="$ROOT/data/status/health.json"

# Default: don’t run more than once every 6h unless something changed.
MIN_INTERVAL_SECONDS=${MIN_INTERVAL_SECONDS:-21600}

now_epoch=$(date -u +%s)
now_iso=$(date -u +%FT%TZ)

health_fingerprint() {
  if [ ! -f "$HEALTH" ]; then
    echo "missing_health" | sha256sum | awk '{print $1}'
    return
  fi

  # Only include fields that indicate material operator work.
  # IMPORTANT: include a git working-tree fingerprint too.
  # Otherwise, a dirty repo (e.g., allowlisted docs mutation) can persist across
  # rate-limited self-improvement runs and never get cleaned up.
  git_dirty_fp=$(git -C "$ROOT" status --porcelain 2>/dev/null | sha256sum | awk '{print $1}')

  jq -c --arg gd "$git_dirty_fp" \
    '{issues:(.issues//[]),blockers:(.blockers//[]),git_dirty:(.git_dirty//null),git_ahead:(.git_ahead//null),git_behind:(.git_behind//null),git_dirty_fp:$gd}' \
    "$HEALTH" 2>/dev/null | sha256sum | awk '{print $1}'
}

last_run_epoch=0
last_fp=""
if [ -f "$STATE" ]; then
  last_run_epoch=$(jq -r '.last_run_epoch // 0' "$STATE" 2>/dev/null || echo 0)
  last_fp=$(jq -r '.fingerprint // ""' "$STATE" 2>/dev/null || echo "")
fi

fp_now=$(health_fingerprint)
age=$(( now_epoch - last_run_epoch ))

if [ "$last_run_epoch" -gt 0 ] && [ "$age" -lt "$MIN_INTERVAL_SECONDS" ] && [ -n "$last_fp" ] && [ "$fp_now" = "$last_fp" ]; then
  # Write a minimal OUT json so downstream scripts don’t break.
  mkdir -p "$(dirname "$OUT")"
  jq -n \
    --arg ts "$now_iso" \
    --arg skip_reason "rate_limited_no_change" \
    ' {
      ts_utc:$ts,
      skipped:true,
      skip_reason:$skip_reason,
      ran:{health:false,kpi:false,site_analytics:false,reddit_refresh:false,git_commit:false,git_push:false},
      before:{issues:null,blockers:null,git_sync_ok:null,git_ahead:null,git_behind:null,git_dirty:null,git_dirty_files:null},
      after:{issues:null,blockers:null,git_sync_ok:null,git_ahead:null,git_behind:null,git_dirty:null,git_dirty_files:null},
      git_push_error:null
    }' > "$OUT"
  echo "$OUT"
  exit 0
fi

# Run the full fixer.
bash "$ROOT/scripts/manual-growth-loop/act-on-issues.sh" >/dev/null 2>&1 || true

# Update fingerprint state from the fresh health file.
fp_after=$(health_fingerprint)
mkdir -p "$(dirname "$STATE")"
jq -n \
  --arg ts "$now_iso" \
  --argjson epoch "$now_epoch" \
  --arg fp "$fp_after" \
  '{ts_utc:$ts,last_run_epoch:$epoch,fingerprint:$fp}' > "$STATE"

echo "$OUT"
