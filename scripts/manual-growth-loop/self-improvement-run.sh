#!/usr/bin/env bash
set -euo pipefail

# self-improvement-run.sh
# Purpose: make self-improvement iterations actually happen (repeatable + auditable).
# - runs the last-5 audit
# - actively applies safe local fixes (measurement/KPI/status/push-if-clean)
# - writes a small, timestamped report to data/status/
# - records a FINISH note indicating what changed
# Safe: local-only writes (data/status + run history). No external sends.

ROOT="/home/jabbit/.openclaw/workspace"
LATEST="$ROOT/data/status/manual-growth-loop-latest.json"
OUTDIR="$ROOT/data/status"

if [ ! -f "$LATEST" ]; then
  echo "missing latest pointer: $LATEST" >&2
  exit 2
fi

iteration=$(jq -r '.iteration' "$LATEST")
mode=$(jq -r '.mode' "$LATEST")

ts=$(date -u +%Y-%m-%dT%H%M%SZ)
report_txt="$OUTDIR/manual-growth-loop-self-improvement-${iteration}-${ts}.txt"
act_json="$OUTDIR/manual-growth-loop-act-on-issues-last.json"

# Crucial: self-improvement should change system state when it safely can.
# Rate-limit heavy local maintenance if nothing has changed recently.
bash "$ROOT/scripts/manual-growth-loop/act-on-issues-rate-limited.sh" >/dev/null 2>&1 || true

# Guardrail: self-improvement runs must not leave the repo dirty due to accidental edits
# to tracked docs. If a background step dirties docs/ without an explicit intent to ship,
# revert it so subsequent runs stay reliable and we don't "silently accumulate" diffs.
# Override by setting ALLOW_DOC_MUTATIONS=1 in the environment.
if [ "${ALLOW_DOC_MUTATIONS:-0}" != "1" ]; then
  dirty_paths=$(git -C "$ROOT" status --porcelain | awk '{print $2}' || true)
  if echo "$dirty_paths" | grep -q '^docs/breaking-topics-radar.md$'; then
    # Only auto-revert if this is the *only* dirty file.
    if [ "$(echo "$dirty_paths" | sed '/^$/d' | wc -l | tr -d ' ')" = "1" ]; then
      git -C "$ROOT" checkout -- docs/breaking-topics-radar.md >/dev/null 2>&1 || true
    fi
  fi
fi

{
  echo "self-improvement-report"
  echo "ts_utc: $(date -u +%FT%TZ)"
  echo "iteration: ${iteration}"
  echo "mode: ${mode}"
  echo
  echo "## act-on-issues (safe local fixes applied first)"
  if [ -f "$act_json" ]; then
    cat "$act_json"
  else
    echo "missing: ${act_json}"
  fi
  echo
  echo "## audit-last-5"
  IGNORE_ITERATION="$iteration" bash "$ROOT/scripts/manual-growth-loop/audit-last-5.sh" || true
  echo
  echo "## operator-next (preflight-derived)"
  bash "$ROOT/scripts/manual-growth-loop/operator-next.sh" || true
  echo

  echo "## churn-report (last 24 distinct iterations)"
  bash "$ROOT/scripts/manual-growth-loop/churn-report.sh" 2>/dev/null || true
  echo

  echo "## cooldown-health (are we wasting hourly runs?)"
  bash "$ROOT/scripts/manual-growth-loop/cooldown-health.sh" 2>/dev/null || true
  echo

  if [ -f "$ROOT/data/status/growth-default-actions-noop-next.txt" ]; then
    echo "## latest noop-next (if recent runs were cooldown NOOPs)"
    sed -n '1,200p' "$ROOT/data/status/growth-default-actions-noop-next.txt" || true
    echo
  fi

  echo "## git working tree (diagnostic)"
  if git -C "$ROOT" diff --quiet && [ -z "$(git -C "$ROOT" status --porcelain)" ]; then
    echo "clean: true"
  else
    echo "clean: false"
    git_dirty_report="$OUTDIR/git-dirty-${iteration}-${ts}.txt"
    {
      echo "ts_utc: $(date -u +%FT%TZ)"
      echo "iteration: ${iteration}"
      echo "---"
      echo "git status --porcelain:"
      git -C "$ROOT" status --porcelain || true
      echo
      echo "git diff --stat:"
      git -C "$ROOT" diff --stat || true
    } >"$git_dirty_report"
    echo "wrote: ${git_dirty_report##$ROOT/}"
  fi
  echo

  echo "## research (cached operator patterns; avoid rate-limit churn)"
  # Keep a tiny local cache of key operator docs so audits don't depend on live fetches.
  bash "$ROOT/scripts/manual-growth-loop/refresh-openclaw-docs.sh" 2>/dev/null || true
  bash "$ROOT/scripts/manual-growth-loop/research-openclaw-patterns.sh" 2>/dev/null || true
  echo

  echo "## recommended process upgrades (operator picks 1-3)"
  echo "- When mode=self-improvement, ALWAYS run this script, then record-finish with what changed."
  echo "- Prefer upgrades that reduce repeat loops: stronger STOP reasons, better next-action surfacing, fewer empty runs."
  echo "- Keep outputs ephemeral unless it changes system state: write to data/status or scripts/, not WORKLOG."
} | tee "$report_txt" >/dev/null

# Record a finish note that this iteration executed the self-improvement harness.
# (If operator also applied other changes, they should record an additional finish note manually.)
ran_summary="unknown"
if [ -f "$act_json" ]; then
  ran_summary=$(jq -r '[.ran | to_entries[] | select(.value==true) | .key] | if length==0 then "none" else join(",") end' "$act_json" 2>/dev/null || echo "unknown")
fi

bash "$ROOT/scripts/manual-growth-loop/record-finish.sh" \
  --tags "R,P" \
  --note "SELF-IMPROVEMENT: ran self-improvement-run.sh, applied safe local fixes=[${ran_summary}], and wrote ${report_txt##$ROOT/}. Next: only escalate issues that truly require owner action." 

echo "wrote: $report_txt"
