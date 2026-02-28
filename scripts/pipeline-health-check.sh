#!/usr/bin/env bash
# Unified Pipeline Health Check
# Runs in seconds, provides quick status of all components.
#
# Usage:
#   bash scripts/pipeline-health-check.sh        # fast checks
#   bash scripts/pipeline-health-check.sh --deep # also run SEO audits (still read-only)

set -euo pipefail

WORKSPACE="/home/jabbit/.openclaw/workspace"
REDIS_DIR="${WORKSPACE}/data/reddit"
TODAY="$(date -u +%Y-%m-%d)"

DEEP=0
if [ "${1:-}" = "--deep" ]; then
  DEEP=1
fi

say_ok()   { echo "  ✅ $*"; }
say_warn() { echo "  ⚠️  $*"; }
say_bad()  { echo "  ❌ $*"; }

# Print Git status for a repo (path provided). This avoids false “pushed today”
# by comparing HEAD vs upstream tracking branch, when available.
git_report() {
  local repo_path="$1"
  local label="$2"

  if ! git -C "$repo_path" rev-parse --git-dir >/dev/null 2>&1; then
    say_warn "$label: not a git repo"
    return 0
  fi

  local upstream=""
  upstream="$(git -C "$repo_path" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"

  local behind=0
  local ahead=0
  if [ -n "$upstream" ]; then
    # rev-list output: "<behind> <ahead>" when using "upstream...HEAD"
    read -r behind ahead < <(git -C "$repo_path" rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || echo "0 0")
  fi

  # Dirty working tree detection (staged/unstaged/untracked)
  local dirty=0
  if ! git -C "$repo_path" diff --quiet 2>/dev/null; then dirty=1; fi
  if ! git -C "$repo_path" diff --cached --quiet 2>/dev/null; then dirty=1; fi
  if [ -n "$(git -C "$repo_path" ls-files --others --exclude-standard 2>/dev/null | head -1 || true)" ]; then dirty=1; fi

  if [ -z "$upstream" ]; then
    say_warn "$label: no upstream tracking branch"
  else
    if [ "${ahead:-0}" -eq 0 ] 2>/dev/null && [ "${behind:-0}" -eq 0 ] 2>/dev/null; then
      say_ok "$label: up to date with $upstream"
    else
      # We keep it simple + actionable.
      if [ "${ahead:-0}" -gt 0 ] 2>/dev/null && [ "${behind:-0}" -gt 0 ] 2>/dev/null; then
        say_warn "$label: diverged (ahead $ahead, behind $behind)"
      elif [ "${ahead:-0}" -gt 0 ] 2>/dev/null; then
        say_warn "$label: ahead of $upstream by $ahead commit(s) (needs push)"
      elif [ "${behind:-0}" -gt 0 ] 2>/dev/null; then
        say_warn "$label: behind $upstream by $behind commit(s) (needs pull)"
      fi
    fi

    # “Pushed today” only when up-to-date AND upstream HEAD commit date is today.
    local upstream_date=""
    upstream_date="$(git -C "$repo_path" log -1 --date=format:%Y-%m-%d --format=%cd "$upstream" 2>/dev/null | head -1 || true)"
    if [ "${ahead:-0}" -eq 0 ] 2>/dev/null && [ "${behind:-0}" -eq 0 ] 2>/dev/null && [ "$upstream_date" = "$TODAY" ]; then
      say_ok "$label: pushed today"
    elif [ -n "$upstream_date" ]; then
      echo "  $label: upstream last commit $upstream_date"
    fi
  fi

  if [ "$dirty" -eq 1 ] 2>/dev/null; then
    say_warn "$label: working tree has uncommitted changes"
  fi
}

echo "=== Pipeline Health Check ==="
echo "Date: $TODAY"
echo ""

# Site Health (timeouts so this never hangs)
echo "🌐 Site:"
HTTP_CODE="$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 6 https://www.jabbitapp.com/ 2>/dev/null || true)"
if [ "$HTTP_CODE" = "200" ]; then
  say_ok "jabbitapp.com ($HTTP_CODE)"
elif [ -z "$HTTP_CODE" ]; then
  say_bad "jabbitapp.com (no response)"
else
  say_bad "jabbitapp.com ($HTTP_CODE)"
fi

# GitHub Sync
# NOTE: We report *truthful* sync status against the upstream branch.
# (Previously this used last commit date as a proxy and could say “pushed today” even when ahead.)
echo ""
echo "📦 GitHub:"
cd "$WORKSPACE" 2>/dev/null || true
if git rev-parse --git-dir >/dev/null 2>&1; then
  say_ok "Git repo initialized"
  git_report "$WORKSPACE" "root"

  # Submodule/site repo (if present)
  if [ -d "$WORKSPACE/jabbitapp.com" ] && git -C "$WORKSPACE/jabbitapp.com" rev-parse --git-dir >/dev/null 2>&1; then
    git_report "$WORKSPACE/jabbitapp.com" "jabbitapp.com"
  fi
else
  say_bad "Git not initialized"
fi

# Circuit Breaker
echo ""
echo "🔄 Circuit Breaker:"
if [ -f "${REDIS_DIR}/.circuit_breaker" ]; then
  # Try JSON format first, then plain text.
  CB_DATE="$(python3 - <<'PY' 2>/dev/null || true
import json, pathlib
p = pathlib.Path('/home/jabbit/.openclaw/workspace/data/reddit/.circuit_breaker')
try:
  doc = json.loads(p.read_text())
  print((doc.get('date') or '').strip())
except Exception:
  pass
PY
)"
  if [ -z "$CB_DATE" ]; then
    CB_DATE="$(tr -d '[:space:]' < "${REDIS_DIR}/.circuit_breaker" 2>/dev/null || true)"
  fi

  if [ "$CB_DATE" = "$TODAY" ]; then
    say_ok "Reset today"
  else
    say_warn "Stale: ${CB_DATE:-unknown}"
  fi
else
  say_bad "Missing"
fi

# Data Directory
echo ""
echo "💾 Data:"
if [ -d "$REDIS_DIR" ]; then
  SIZE="$(du -sh "$REDIS_DIR" 2>/dev/null | cut -f1 || true)"
  echo "  Reddit data: ${SIZE:-unknown}"

  # Check for stale files (older than 2 days = 2880 minutes)
  STALE="$(find "$REDIS_DIR" -type f -name "*.json" -mmin +2880 2>/dev/null | wc -l | tr -d ' ' || true)"
  if [ "${STALE:-0}" -gt 0 ] 2>/dev/null; then
    say_warn "$STALE stale files (>2 days)"
  else
    say_ok "No stale files"
  fi
else
  say_bad "Reddit data missing"
fi

# Email
echo ""
echo "📧 Email:"
if [ -n "${RESEND_API_KEY:-}" ]; then
  say_ok "API key configured"
else
  say_bad "No API key"
fi

# Twitter
echo ""
echo "🐦 Twitter:"
TWITTER_STATE="${WORKSPACE}/data/twitter_post_state.json"
if [ -f "$TWITTER_STATE" ]; then
  LAST_POST=""
  if command -v jq >/dev/null 2>&1; then
    LAST_POST="$(jq -r '.last_post_time // empty' "$TWITTER_STATE" 2>/dev/null || true)"
    if [ "$LAST_POST" = "null" ]; then LAST_POST=""; fi
  fi
  if [ -z "$LAST_POST" ]; then
    # fallback (best-effort)
    LAST_POST="$(grep -o '"last_post_time"\s*:\s*[^,}]*' "$TWITTER_STATE" 2>/dev/null | head -1 | cut -d: -f2- | tr -d ' "' || true)"
    if [ "$LAST_POST" = "null" ]; then LAST_POST=""; fi
  fi

  if [ -n "$LAST_POST" ]; then
    echo "  Last post: $LAST_POST"
  else
    say_warn "No successful posts"
  fi
else
  say_bad "No state file"
fi

# Disk & Memory
echo ""
echo "💻 System:"
DISK="$(df -h /home/jabbit 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' || true)"
echo "  Disk: ${DISK:-?}%"

MEM_AVAIL="$(free -m 2>/dev/null | awk 'NR==2{print $7}' || true)"
echo "  Memory available: ${MEM_AVAIL:-?}MB"

if [ "$DEEP" = "1" ]; then
  echo ""
  echo "🔍 SEO Audits (deep, read-only):"
  if bash "$WORKSPACE/scripts/html-seo-audit.sh" >/dev/null 2>&1; then say_ok "html-seo-audit"; else say_bad "html-seo-audit"; fi
  if bash "$WORKSPACE/scripts/sitemap-audit.sh" >/dev/null 2>&1; then say_ok "sitemap-audit"; else say_bad "sitemap-audit"; fi
  if python3 "$WORKSPACE/scripts/internal-link-audit.py" >/dev/null 2>&1; then say_ok "internal-link-audit"; else say_bad "internal-link-audit"; fi
  if python3 "$WORKSPACE/scripts/faq-jsonld-sync.py" --check --json >/dev/null 2>&1; then say_ok "faq-jsonld-sync"; else say_bad "faq-jsonld-sync"; fi
fi

echo ""
echo "=== Summary ==="
echo "Run this script anytime to get a quick pipeline status."