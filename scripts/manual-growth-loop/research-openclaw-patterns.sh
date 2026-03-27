#!/usr/bin/env bash
set -euo pipefail

# research-openclaw-patterns.sh
# Purpose: lightweight research step for self-improvement runs.
# - Avoids hammering web search (rate-limited)
# - Caches an operator-pattern snippet under data/status/
# - Seeds from local docs + *occasionally* refreshed external docs
#
# NOTE: This script intentionally does *not* call web_search/web_fetch itself.
# In OpenClaw, those are chat-tools, not shell tools. When we do external research
# in a deliberate self-improvement run, we paste distilled findings into the cache
# (below) and let the cache fan out to future runs.

ROOT="/home/jabbit/.openclaw/workspace"
OUTDIR="$ROOT/data/status"
CACHE="$OUTDIR/openclaw-operator-patterns-cache.md"

# Default cache TTL: 24h (self-improvement runs are every 5 hours; 12h TTL caused
# needless churn without meaningfully improving execution quality).
MAX_AGE_SECONDS=$((24*60*60))

# Bump this when cache content format/sections change so old caches regenerate.
CACHE_SCHEMA="cache_schema: 2"

now_epoch=$(date -u +%s)

cache_age_ok() {
  [ -f "$CACHE" ] || return 1
  local m
  m=$(stat -c %Y "$CACHE" 2>/dev/null || echo 0)
  [ "$m" -gt 0 ] || return 1
  local age=$((now_epoch - m))
  [ "$age" -lt "$MAX_AGE_SECONDS" ]
}

cache_schema_ok() {
  [ -f "$CACHE" ] || return 1
  grep -q "$CACHE_SCHEMA" "$CACHE" 2>/dev/null
}

mkdir -p "$OUTDIR"

# FORCE_REFRESH=1 bypasses TTL (for deliberate operator refreshes).
if [ "${FORCE_REFRESH:-0}" != "1" ] && cache_age_ok && cache_schema_ok; then
  cat "$CACHE"
  exit 0
fi

# Brave/web_search can be rate-limited in this environment.
# Keep the cache mostly stable; refresh only when we have new, high-signal findings.

{
  echo "# OpenClaw operator patterns (cached)"
  echo
  echo "$CACHE_SCHEMA"
  echo "updated_utc: $(date -u +%FT%TZ)"
  echo
  echo "## Reliability-first patterns we will follow"
  echo "- Evidence bundle: every run should leave inspectable artifacts (JSONL run log + any local side-effects) so audits are trivial."
  echo "- No empty loops: each loop either (a) advances state or (b) STOPs with a single owner/action that advances state (no draft churn)."
  echo "- Rate-limit nudges: when blocked on a human, generate one stable 'owner pack' artifact and throttle follow-ups; don't regenerate new drafts hourly."
  echo "- Cooldowns must match cadence: an hourly job needs ≥1 cheap eligible action; if all lanes are cooling down, pivot to measurement integrity/backlog maintenance."
  echo
  echo "## Cron/heartbeat execution model (distilled)"
  echo "- Cron runs inside the Gateway; jobs persist under ~/.openclaw/cron/jobs.json (manual edits only safe when gateway is stopped)."
  echo "- Main session jobs enqueue a systemEvent; depending on wakeMode they run immediately (wakeMode=now) or on the next heartbeat (wakeMode=next-heartbeat)."
  echo "- Isolated jobs run a dedicated agent turn in cron:<jobId> and (by default) deliver via delivery.mode=announce unless disabled."
  echo "- Delivery modes: announce | webhook | none (use webhook for machine delivery, announce for chat delivery)."
  echo
  echo "## Known reliability bug (important)"
  echo "- Reported: sessionTarget=main systemEvent jobs can inject the event but not reliably wake the agent until a heartbeat/user message occurs (OpenClaw 2026.2.x reports)."
  echo "  Mitigation: prefer sessionTarget=isolated + payload.kind=agentTurn + delivery.mode=announce/webhook for time-sensitive delivery."
  echo
  echo "## Local docs to keep in mind"
  [ -f "$ROOT/docs/cron-edit-safety.md" ] && echo "- docs/cron-edit-safety.md (job storage + safe edits)"
  [ -f "$ROOT/docs/manual-growth-loop-playbook.md" ] && echo "- docs/manual-growth-loop-playbook.md (guardrails + de-dupe)"
  echo
  echo "## Source links (operator verification)"
  echo "- https://openclawlab.com/en/docs/automation/cron-jobs/"
  echo "- https://openclawlab.com/en/docs/automation/cron-vs-heartbeat/"
  echo "- https://github.com/openclaw/openclaw/issues/11726"
} >"$CACHE"

cat "$CACHE"
