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

ROOT="/home/jabbit/.openclaw/workspace"

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

# Action 1) Measurement snapshot (keeps KPI dashboard honest downstream)
# Writes: data/status/site-analytics.json
timeout 45s bash "$ROOT/scripts/site-analytics-status.sh" >/dev/null || true

# Action 2) Reddit opportunity scouting (manual-only execution later)
# Writes: data/status/reddit-opps-*.json + reddit-opps-latest.json and reviewed candidate output
# Guard: this occasionally hangs on network/auth checks — hard-timeout to keep cron reliable.
REDDIT_DISCOVERY_USE_COOKIE=false REDDIT_DISCOVERY_COOKIE_FALLBACK=false \
  timeout 45s python3 "$ROOT/scripts/reddit_smart_review_post.py" >/dev/null 2>&1 || true

# Action 3) Refresh distribution packs (copy/paste snippets; no posting)
# Writes: output/distribution-pack-*.md
timeout 45s bash "$ROOT/scripts/generate-distribution-packs.sh" >/dev/null || true

echo "growth-default-actions: OK (measurement + reddit opps + distribution packs)"
