#!/usr/bin/env bash
set -euo pipefail

# research-openclaw-patterns.sh
# Purpose: lightweight "research" step for self-improvement runs.
# - Avoids hammering web search (rate-limited)
# - Caches an operator-pattern snippet under data/status/
# - Always includes pointers to local reliability docs in-repo
#
# NOTE: This script intentionally does *not* call web_search/web_fetch itself.
# In OpenClaw, those are chat-tools, not shell tools. When we do external research
# in a self-improvement run, we should paste distilled findings into the cache
# (below) and let the cache fan out to future runs.

ROOT="/home/jabbit/.openclaw/workspace"
OUTDIR="$ROOT/data/status"
CACHE="$OUTDIR/openclaw-operator-patterns-cache.md"
MAX_AGE_SECONDS=$((12*60*60))

now_epoch=$(date -u +%s)

cache_age_ok() {
  [ -f "$CACHE" ] || return 1
  local m
  m=$(stat -c %Y "$CACHE" 2>/dev/null || echo 0)
  [ "$m" -gt 0 ] || return 1
  local age=$((now_epoch - m))
  [ "$age" -lt "$MAX_AGE_SECONDS" ]
}

mkdir -p "$OUTDIR"

if cache_age_ok; then
  cat "$CACHE"
  exit 0
fi

# Brave/web_search can be rate-limited in this environment.
# Keep this cache seeded from local docs + a small curated set of patterns.

{
  echo "# OpenClaw operator patterns (cached)"
  echo
  echo "updated_utc: $(date -u +%FT%TZ)"
  echo
  echo "## Patterns we will follow"
  echo "- Reliability = evidence: every run should leave behind durable, inspectable artifacts (JSONL run log + any local side-effects) so we can explain/verify what happened later."
  echo "- Single-writer invariant: serialize state changes through one lane/session at a time; avoid multi-turn cron flows that depend on yield/resume."
  echo "- Prefer isolated cron agentTurn jobs for stateless chores; reserve main-session systemEvent jobs for work that truly needs main context, and pick wakeMode deliberately (now vs next-heartbeat)."
  echo "- Every loop should either (a) advance state or (b) STOP with a single, concrete owner/action that advances state (no draft churn)."
  echo "- Reduce empty runs: align cooldowns with schedule (hourly loop should have ≥1 cheap eligible action); if both scouting lanes are cooling down, pivot to backlog/measurement integrity checks." 
  echo "- When blocked on human action, generate a stable ‘owner pack’ artifact once, then rate-limit nudges (don’t churn new drafts)."
  echo
  echo "## Known edge cases / gotchas (recent)"
  echo "- Cron main-session jobs can fail to wake/process injected systemEvents in some versions (systemEvent sits until next heartbeat/user message). Mitigation: prefer sessionTarget=\"isolated\" + payload.kind=\"agentTurn\" with delivery.mode=announce/webhook for anything that must deliver reliably." 
  echo "- cron + isolated sessions: sessions_yield behavior has had regressions/bugs in some OpenClaw releases; avoid designing cron flows that require multi-turn yield/resume. Prefer delivery=announce/webhook for results, and keep runs single-turn deterministic."
  echo
  echo "## Local docs to keep in mind"
  if [ -f "$ROOT/docs/cron-edit-safety.md" ]; then
    echo "- docs/cron-edit-safety.md (job storage + safe edits)"
  fi
  if [ -f "$ROOT/docs/manual-growth-loop-playbook.md" ]; then
    echo "- docs/manual-growth-loop-playbook.md (guardrails + de-dupe)"
  fi
  echo
  echo "## External references (for the next deliberate research run)"
  echo "- https://openclawlab.com/en/docs/automation/cron-jobs/ (cron concepts: wakeMode, delivery modes, storage)"
  echo "- https://openclawlab.com/en/docs/automation/cron-vs-heartbeat/ (when to use which)"
  echo "- https://theagentstack.substack.com/p/openclaw-architecture-part-6-reliability (reliability/observability: lanes, dedupe, evidence bundles)"
  echo "- https://github.com/openclaw/openclaw/issues/11726 (main sessionTarget wake bug report)"
  echo "- https://github.com/openclaw/openclaw/issues/46298"
  echo "- https://github.com/openclaw/openclaw/issues/49572"
} >"$CACHE"

cat "$CACHE"
