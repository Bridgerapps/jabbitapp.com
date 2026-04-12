#!/usr/bin/env bash
set -euo pipefail

# cron-sanity-check.sh
# Purpose: quick, non-secret sanity check for cron job settings that affect reliability.
# - Focus: manual-growth-loop-hourly job(s)
# - Prints only a minimal, non-sensitive subset of job fields.
# Safe: read-only.

JOBS_FILE="${OPENCLAW_CRON_JOBS_FILE:-$HOME/.openclaw/cron/jobs.json}"

if [ ! -f "$JOBS_FILE" ]; then
  echo "cron-sanity-check: missing jobs file: $JOBS_FILE" >&2
  exit 0
fi

# Some installations store {jobs:[...]} while others store an array.
# Normalize to an array inline.
jq -r \
  --arg name_pat "manual-growth-loop" \
  'if type=="array" then . else (.jobs // []) end
   | map(select((.name // "") | test($name_pat)))
   | map({
       id:(.id // .jobId // null),
       name:(.name // null),
       enabled:(.enabled // true),
       schedule:(.schedule.kind // null),
       schedule_expr:(.schedule.expr // null),
       sessionTarget:(.sessionTarget // null),
       payload_kind:(.payload.kind // null),
       model:(.payload.model // null),
       thinking:(.payload.thinking // null),
       delivery_mode:(.delivery.mode // null),
       delivery_channel:(.delivery.channel // null),
       delivery_to:(.delivery.to // null),
       warn_delivery_none:(if (.delivery.mode // "none") == "none" then true else false end),
       warn_delivery_mismatch:(if ((.sessionTarget // "") == "isolated") and ((.delivery.mode // "none") == "none") then "isolated+delivery.none -> likely silent (no announce/webhook)" else null end)
     })
   | if length==0 then "cron-sanity-check: no matching jobs" else ("cron-sanity-check: matching jobs=" + (length|tostring) + "\n" + (tojson)) end' \
  "$JOBS_FILE" 2>/dev/null || echo "cron-sanity-check: jq failed (jobs.json schema changed?)"
