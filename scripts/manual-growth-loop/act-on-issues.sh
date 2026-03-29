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
ran_git_commit=false
ran_git_push=false
git_push_error=""

git_dirty_files_before=""

git_dirty_before=$(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [ "${git_dirty_before:-0}" != "0" ]; then
  git_dirty_files_before=$(git -C "$ROOT" status --porcelain 2>/dev/null | sed -n '1,200p' || true)
fi

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

# 4) Auto-fix common low-risk SEO blockers (keeps health-check green without manual babysitting).
#    - Sitemap mismatch is usually just a stale sitemap.xml.
#    - Related-links coverage missing is usually a missing rule for a new page.
#    These are safe local fixes (no external sends).
if [ -f "$HEALTH" ]; then
  sitemap_missing=$(jq -r '.sitemap_missing_count // 0' "$HEALTH" 2>/dev/null || echo 0)
  if [ "$sitemap_missing" != "0" ]; then
    python3 "$ROOT/scripts/generate-sitemap.py" >/dev/null 2>&1 || true
  fi

  rl_missing=$(jq -r '.related_links_missing_count // 0' "$HEALTH" 2>/dev/null || echo 0)
  if [ "$rl_missing" != "0" ]; then
    # Apply suggested related-links rules for missing pages (idempotent).
    python3 - <<'PY' >/dev/null 2>&1 || true
import json
from pathlib import Path
root = Path('/home/jabbit/.openclaw/workspace')
res = json.loads((__import__('subprocess').check_output(['python3', str(root/'scripts/related-links-suggest.py'), '--json'])).decode('utf-8'))
rules_path = root/'data/seo/related-links.json'
if not rules_path.exists():
    raise SystemExit(0)
data = json.loads(rules_path.read_text())
rules = data.get('rules', [])
existing = {r.get('file') for r in rules if isinstance(r, dict)}
for s in res.get('suggestions', []):
    f = s.get('file')
    links = s.get('links')
    if f and f not in existing and isinstance(links, list) and links:
        rules.append({'file': f, 'links': links})
        existing.add(f)
if rules != data.get('rules', []):
    data['rules'] = rules
    data['updated'] = __import__('datetime').datetime.utcnow().replace(microsecond=0).isoformat() + 'Z'
    rules_path.write_text(json.dumps(data, indent=2) + '\n')
PY
  fi
fi

# 5) If Reddit telemetry is stale/unknown, refresh the public health probe + canonical status.
reddit_fresh=$(jq -r '.reddit_fresh // false' "$SYSTEMS" 2>/dev/null || echo false)
reddit_status=$(jq -r '.reddit // "unknown"' "$SYSTEMS" 2>/dev/null || echo unknown)
if [ "$reddit_fresh" != "true" ] || [ "$reddit_status" = "unknown" ]; then
  bash "$ROOT/scripts/reddit-health-check.sh" >/dev/null 2>&1 || true
  bash "$ROOT/scripts/reddit-telemetry.sh" >/dev/null 2>&1 || true
  ran_reddit_refresh=true
fi

# 6) Reliability upgrade: if we created *only* low-risk, deterministic local files, auto-commit them.
#    This reduces recurring health-check noise (git_dirty) and keeps the loop auditable.
#    Guardrail: refuse to commit if unexpected paths are modified.
commit_whitelist_regex='^(docs/kpi-[0-9]{4}-[0-9]{2}-[0-9]{2}\\.md|data/status/|data/seo/related-links\\.json|site/sitemap\\.xml)$'

git_dirty=$(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [ "${git_dirty:-0}" != "0" ]; then
  changed_files=$(git -C "$ROOT" status --porcelain 2>/dev/null | awk '{print $2}' | sed '/^$/d' || true)
  unexpected=""
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if ! echo "$f" | grep -Eq "$commit_whitelist_regex"; then
      unexpected+="$f\n"
    fi
  done <<<"$changed_files"

  if [ -z "$unexpected" ]; then
    # Stage only the expected files.
    git -C "$ROOT" add -A -- \
      docs/kpi-*.md \
      data/status \
      data/seo/related-links.json \
      site/sitemap.xml \
      >/dev/null 2>&1 || true

    if git -C "$ROOT" diff --cached --quiet; then
      :
    else
      if git -C "$ROOT" commit -m "chore: auto-fix health/KPI status" >/dev/null 2>&1; then
        ran_git_commit=true
      fi
    fi
  fi
fi

# 7) Guardrail: prevent accidental tracked-doc churn from blocking auto-push.
#    We've seen background checks touch docs/breaking-topics-radar.md opportunistically.
#    In self-improvement mode we want the repo clean + auditable; revert that file if it's
#    the only dirty path and the operator didn't explicitly allow doc mutations.
if [ "${ALLOW_DOC_MUTATIONS:-0}" != "1" ]; then
  dirty_paths=$(git -C "$ROOT" status --porcelain | awk '{print $2}' | sed '/^$/d' || true)
  if echo "$dirty_paths" | grep -q '^docs/breaking-topics-radar.md$'; then
    if [ "$(echo "$dirty_paths" | wc -l | tr -d ' ')" = "1" ]; then
      git -C "$ROOT" checkout -- docs/breaking-topics-radar.md >/dev/null 2>&1 || true
      # Re-run health-check so git status fields in the report reflect the revert.
      bash "$ROOT/scripts/health-check.sh" >/dev/null 2>&1 || true
    fi
  fi
fi

# 8) If repo is ahead but clean and not behind, push automatically.
#    This is internal-only and lowers recurring health noise.
repo_dirty=$(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
read -r behind ahead < <(git -C "$ROOT" rev-list --left-right --count origin/main...HEAD 2>/dev/null || echo '0 0')
if [ "$repo_dirty" = "0" ] && [ "${ahead:-0}" -gt 0 ] 2>/dev/null && [ "${behind:-0}" = "0" ]; then
  push_err=$(mktemp)
  if git -C "$ROOT" push origin main >/dev/null 2>"$push_err"; then
    ran_git_push=true
  else
    # Capture the error for the self-improvement report (prevents silent push failures).
    git_push_error=$(sed -n '1,200p' "$push_err" | tr -d '\r' || true)
  fi
  rm -f "$push_err" >/dev/null 2>&1 || true
fi

# Final refresh so status files reflect any fixes/commit/push we applied.
bash "$ROOT/scripts/health-check.sh" >/dev/null 2>&1 || true

health_after='{}'
if [ -f "$HEALTH" ]; then
  health_after=$(cat "$HEALTH" 2>/dev/null || echo '{}')
fi

git_dirty_after=$(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
git_dirty_files_after=""
if [ "${git_dirty_after:-0}" != "0" ]; then
  git_dirty_files_after=$(git -C "$ROOT" status --porcelain 2>/dev/null | sed -n '1,200p' || true)
fi

jq -n \
  --arg ts "$(date -u +%FT%TZ)" \
  --argjson ran_health "$ran_health" \
  --argjson ran_kpi "$ran_kpi" \
  --argjson ran_site_analytics "$ran_site_analytics" \
  --argjson ran_reddit_refresh "$ran_reddit_refresh" \
  --argjson ran_git_commit "$ran_git_commit" \
  --argjson ran_git_push "$ran_git_push" \
  --arg git_push_error "$git_push_error" \
  --argjson health_before "$health_before" \
  --argjson health_after "$health_after" \
  --arg git_dirty_files_before "$git_dirty_files_before" \
  --arg git_dirty_files_after "$git_dirty_files_after" \
  ' {
    ts_utc:$ts,
    ran:{health:$ran_health,kpi:$ran_kpi,site_analytics:$ran_site_analytics,reddit_refresh:$ran_reddit_refresh,git_commit:$ran_git_commit,git_push:$ran_git_push},
    before:{issues:($health_before.issues // []),blockers:($health_before.blockers // []),git_sync_ok:($health_before.git_sync_ok // null),git_ahead:($health_before.git_ahead // null),git_behind:($health_before.git_behind // null),git_dirty:($health_before.git_dirty // null),git_dirty_files:($git_dirty_files_before | if length>0 then . else null end)},
    after:{issues:($health_after.issues // []),blockers:($health_after.blockers // []),git_sync_ok:($health_after.git_sync_ok // null),git_ahead:($health_after.git_ahead // null),git_behind:($health_after.git_behind // null),git_dirty:($health_after.git_dirty // null),git_dirty_files:($git_dirty_files_after | if length>0 then . else null end)},
    git_push_error:($git_push_error | if length>0 then . else null end)
  }' > "$OUT"

echo "$OUT"
