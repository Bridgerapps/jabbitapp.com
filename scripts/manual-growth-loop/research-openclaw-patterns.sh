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
  echo "- Prefer isolated cron agentTurn jobs for stateless chores; main-session systemEvent jobs must be fully self-contained."
  echo "- Every loop should either (a) advance state or (b) STOP with a single, concrete next action that advances state."
  echo "- Reduce empty runs: align cooldowns with schedule (hourly loop should have >=1 cheap action eligible each hour)."
  echo "- When a loop is blocked on human action, generate a stable ‘owner pack’ artifact once, then rate-limit nudges (don’t churn new drafts)."
  echo
  echo "## Known edge cases / gotchas (recent)"
  echo "- cron + isolated sessions: sessions_yield behavior has had regressions/bugs in recent OpenClaw releases; avoid designing cron flows that require multi-turn yield/resume. Prefer delivery=announce/webhook for results, and keep runs single-turn deterministic."
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
  echo "- https://openclaw-setup.me/blog/openclaw-internals/openclaw-cron-jobs-guide/"
  echo "- https://github.com/openclaw/openclaw/issues/46298"
  echo "- https://github.com/openclaw/openclaw/issues/49572"
} >"$CACHE"

cat "$CACHE"
