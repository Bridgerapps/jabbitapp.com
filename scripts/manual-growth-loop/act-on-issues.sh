#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/jabbit/.openclaw/workspace"
OUT="$ROOT/data/status/manual-growth-loop-act-on-issues-last.json"
HEALTH="$ROOT/data/status/health.json"
SYSTEMS="$ROOT/data/status/systems.json"

mkdir -p "$(dirname "$OUT")"

ran_health=false
ran_kpi=false
ran_site_analytics=false
ran_reddit_refresh=false
ran_git_push=false

health_before='{}'
if [ -f "$HEALTH" ]; then
  health_before=$(cat "$HEALTH" 2>/dev/null || echo '{}')
fi

# 1) Refresh local truth first so decisions are based on current state.
if bash "$ROOT/scripts/health-check.sh" >/dev/null 2>&1; then
  ran_health=true
fi

# 2) Fix stale/missing KPI/dashboard state.
if bash "$ROOT/scripts/manual-growth-loop/ensure-kpi-today.sh" --force >/dev/null 2>&1; then
  if bash "$ROOT/scripts/manual-growth-loop/ensure-kpi-fresh.sh" >/dev/null 2>&1; then
    ran_kpi=true
  fi
fi

# 3) Refresh measurement snapshot explicitly.
if bash "$ROOT/scripts/site-analytics-status.sh" >/dev/null 2>&1; then
  ran_site_analytics=true
fi

# 4) If Reddit telemetry is stale/unknown, refresh the public health probe + canonical status.
reddit_fresh=$(jq -r '.reddit_fresh // false' "$SYSTEMS" 2>/dev/null || echo false)
reddit_status=$(jq -r '.reddit // "unknown"' "$SYSTEMS" 2>/dev/null || echo unknown)
if [ "$reddit_fresh" != "true" ] || [ "$reddit_status" = "unknown" ]; then
  bash "$ROOT/scripts/reddit-health-check.sh" >/dev/null 2>&1 || true
  bash "$ROOT/scripts/reddit-telemetry.sh" >/dev/null 2>&1 || true
  ran_reddit_refresh=true
fi

# 5) If repo is ahead but clean and not behind, push automatically.
#    This is internal-only and lowers recurring health noise.
repo_dirty=$(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
read -r behind ahead < <(git -C "$ROOT" rev-list --left-right --count origin/main...HEAD 2>/dev/null || echo '0 0')
if [ "$repo_dirty" = "0" ] && [ "${ahead:-0}" -gt 0 ] 2>/dev/null && [ "${behind:-0}" = "0" ]; then
  if git -C "$ROOT" push origin main >/dev/null 2>&1; then
    ran_git_push=true
  fi
fi

# Final refresh so status files reflect any fixes/pushes we applied.
bash "$ROOT/scripts/health-check.sh" >/dev/null 2>&1 || true

health_after='{}'
if [ -f "$HEALTH" ]; then
  health_after=$(cat "$HEALTH" 2>/dev/null || echo '{}')
fi

jq -n \
  --arg ts "$(date -u +%FT%TZ)" \
  --argjson ran_health "$ran_health" \
  --argjson ran_kpi "$ran_kpi" \
  --argjson ran_site_analytics "$ran_site_analytics" \
  --argjson ran_reddit_refresh "$ran_reddit_refresh" \
  --argjson ran_git_push "$ran_git_push" \
  --argjson health_before "$health_before" \
  --argjson health_after "$health_after" \
  '{
    ts_utc:$ts,
    ran:{health:$ran_health,kpi:$ran_kpi,site_analytics:$ran_site_analytics,reddit_refresh:$ran_reddit_refresh,git_push:$ran_git_push},
    before:{issues:($health_before.issues // []),blockers:($health_before.blockers // []),git_sync_ok:($health_before.git_sync_ok // null),git_ahead:($health_before.git_ahead // null),git_behind:($health_before.git_behind // null),git_dirty:($health_before.git_dirty // null)},
    after:{issues:($health_after.issues // []),blockers:($health_after.blockers // []),git_sync_ok:($health_after.git_sync_ok // null),git_ahead:($health_after.git_ahead // null),git_behind:($health_after.git_behind // null),git_dirty:($health_after.git_dirty // null)}
  }' > "$OUT"

echo "$OUT"
