#!/usr/bin/env bash
set -euo pipefail

# research-openclaw-patterns.sh
# Purpose: lightweight "research" step for self-improvement runs.
# - Avoids hammering web search (rate-limited)
# - Caches an operator-pattern snippet under data/status/
# - Always includes a pointer to local reliability docs in-repo
# Safe: local-only writes. No network unless explicitly enabled later.

ROOT="/home/jabbit/.openclaw/workspace"
OUTDIR="$ROOT/data/status"
CACHE="$OUTDIR/openclaw-operator-patterns-cache.md"
MAX_AGE_SECONDS=$((24*60*60))

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

# NOTE: Brave/web_search is heavily rate-limited in this environment.
# We intentionally keep this cache seeded from *local* docs plus a short
# manually-curated set of patterns. When web research is possible, update
# this file by hand in a dedicated run.

{
  echo "# OpenClaw operator patterns (cached)"
  echo
  echo "updated_utc: $(date -u +%FT%TZ)"
  echo
  echo "## Patterns we will follow"
  echo "- Prefer isolated cron agentTurn jobs for stateless chores; main-session systemEvent jobs must be fully self-contained (main sessions can compact context)."
  echo "- Every loop should either (a) advance state or (b) make the next state-advancing action unmistakably obvious (STOP with a single next action)."
  echo "- Reduce empty runs: align cooldowns with schedule (hourly loop should have at least one cheap action eligible each hour)."
  echo
  echo "## Local docs to keep in mind"
  if [ -f "$ROOT/docs/cron-edit-safety.md" ]; then
    echo "- docs/cron-edit-safety.md (job storage + safe edits)"
  fi
  if [ -f "$ROOT/docs/manual-growth-loop-playbook.md" ]; then
    echo "- docs/manual-growth-loop-playbook.md (guardrails + de-dupe)"
  fi
} >"$CACHE"

cat "$CACHE"
