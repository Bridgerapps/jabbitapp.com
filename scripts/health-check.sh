#!/bin/bash
# Enhanced Health Check with Alerting
# Checks: site, github sync, reddit data, disk, memory, recent commits, seo pages
# Outputs status and saves to log

WORKSPACE="${WORKSPACE:-/home/jabbit/.openclaw/workspace}"
# The deployable website is a standalone git repository nested inside the
# OpenClaw workspace.  Keep operational state in WORKSPACE, but audit git and
# site content from this repository (the workspace root still contains legacy
# site copies and is not a truthful deployment source).
SITE_REPO="${SITE_REPO:-$WORKSPACE/jabbitapp.com}"
LOG_FILE="$WORKSPACE/logs/health-$(date +%Y-%m-%d).log"
STATUS_FILE="$WORKSPACE/data/status/health.json"

mkdir -p "$WORKSPACE/logs"
mkdir -p "$WORKSPACE/data/status"

# Prevent overlapping health-check runs (cron collisions / manual runs)
LOCK_FILE="$WORKSPACE/data/status/health-check.lock"
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE"
  flock -n 9 || exit 0
fi

echo "=== Health Check $(date) ===" >> "$LOG_FILE"

ISSUES=()
BLOCKERS=()

# Defaults so JSON always has stable keys
REDDIT_STATUS="UNKNOWN"
REDDIT_FRESH="false"
REDDIT_AGE="null"
KARMA_TOTAL="null"
KARMA_STALE="true"

# HTML SEO audit defaults
HTML_SEO_AUDIT_OK="null"
HTML_SEO_ISSUE_COUNT="null"

# Sitemap audit defaults
SITEMAP_AUDIT_OK="null"
SITEMAP_MISSING_COUNT="null"
SITEMAP_EXTRA_COUNT="null"
ROBOTS_SITEMAP_OK="null"

# Internal link audit defaults
INTERNAL_LINK_AUDIT_OK="null"
INTERNAL_LINK_BROKEN_COUNT="null"

# Related-links coverage defaults
RELATED_LINKS_COVERAGE_OK="null"
RELATED_LINKS_MISSING_COUNT="null"
RELATED_LINKS_SUGGESTED_COUNT="null"

# FAQ JSON-LD audit defaults
FAQ_JSONLD_AUDIT_OK="null"
FAQ_JSONLD_CHANGED_COUNT="null"
FAQ_JSONLD_ERROR_COUNT="null"

# 1. Site health
SITE_URL="https://jabbitapp.com/"
# Follow redirects and evaluate the final status code (avoid false positives on 301/302/307).
SITE_CODE="$(curl -sS -L --connect-timeout 5 --max-time 10 -o /dev/null -w '%{http_code}' "$SITE_URL" 2>/dev/null || true)"
case "$SITE_CODE" in
    [0-9][0-9][0-9]) ;;
    *) SITE_CODE="000" ;;
esac
if [ "$SITE_CODE" -ge 200 ] 2>/dev/null && [ "$SITE_CODE" -lt 400 ] 2>/dev/null; then
    echo "✅ Site: HTTP $SITE_CODE ($SITE_URL)" >> "$LOG_FILE"
else
    echo "❌ Site: HTTP $SITE_CODE ($SITE_URL)" >> "$LOG_FILE"
    ISSUES+=("Site down: HTTP $SITE_CODE")
fi

# 2. Git sync (truthful upstream comparison)
TODAY=$(date +%Y-%m-%d)
GIT_UPSTREAM=""
GIT_AHEAD=0
GIT_BEHIND=0
GIT_DIRTY=false
GIT_DIRTY_COUNT=0
GIT_DIRTY_FILES_JSON='[]'
GIT_UPSTREAM_DATE=""
GIT_SYNC_OK=false
GIT_PUSHED_TODAY=false

if git -C "$SITE_REPO" rev-parse --git-dir >/dev/null 2>&1; then
    GIT_UPSTREAM="$(git -C "$SITE_REPO" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"

    if [ -n "$GIT_UPSTREAM" ]; then
        read -r GIT_BEHIND GIT_AHEAD < <(git -C "$SITE_REPO" rev-list --left-right --count "${GIT_UPSTREAM}...HEAD" 2>/dev/null || echo "0 0")
        GIT_UPSTREAM_DATE="$(git -C "$SITE_REPO" log -1 --date=format:%Y-%m-%d --format=%cd "$GIT_UPSTREAM" 2>/dev/null | head -1 || true)"

        if [ "${GIT_AHEAD:-0}" -eq 0 ] 2>/dev/null && [ "${GIT_BEHIND:-0}" -eq 0 ] 2>/dev/null; then
            GIT_SYNC_OK=true
        fi

        if [ "$GIT_SYNC_OK" = true ] && [ "$GIT_UPSTREAM_DATE" = "$TODAY" ]; then
            GIT_PUSHED_TODAY=true
        fi

        if [ "$GIT_SYNC_OK" = true ]; then
            echo "✅ Git: Up to date with $GIT_UPSTREAM" >> "$LOG_FILE"
        else
            echo "⚠️ Git: ahead=${GIT_AHEAD:-0} behind=${GIT_BEHIND:-0} vs $GIT_UPSTREAM" >> "$LOG_FILE"
            if [ "${GIT_AHEAD:-0}" -gt 0 ] 2>/dev/null; then
                ISSUES+=("Git needs push (ahead ${GIT_AHEAD} vs ${GIT_UPSTREAM})")
            fi
            if [ "${GIT_BEHIND:-0}" -gt 0 ] 2>/dev/null; then
                ISSUES+=("Git needs pull/rebase (behind ${GIT_BEHIND} vs ${GIT_UPSTREAM})")
                BLOCKERS+=("Git behind upstream")
            fi
        fi

        if [ "$GIT_PUSHED_TODAY" = true ]; then
            echo "✅ Git: Pushed today" >> "$LOG_FILE"
        else
            echo "ℹ️ Git: upstream last commit ${GIT_UPSTREAM_DATE:-unknown}" >> "$LOG_FILE"
        fi

    else
        echo "⚠️ Git: No upstream tracking branch" >> "$LOG_FILE"
        ISSUES+=("Git has no upstream tracking branch")
    fi

    # Dirty working tree
    if ! git -C "$SITE_REPO" diff --quiet 2>/dev/null; then GIT_DIRTY=true; fi
    if ! git -C "$SITE_REPO" diff --cached --quiet 2>/dev/null; then GIT_DIRTY=true; fi
    if [ -n "$(git -C "$SITE_REPO" ls-files --others --exclude-standard 2>/dev/null | head -1 || true)" ]; then GIT_DIRTY=true; fi

    if [ "$GIT_DIRTY" = true ]; then
        # Provide a small, actionable summary for dashboards/logs.
        # Keep it bounded so status JSON stays small.
        GIT_DIRTY_COUNT=$(git -C "$SITE_REPO" status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo 0)
        GIT_DIRTY_FILES_JSON=$(
          git -C "$SITE_REPO" status --porcelain 2>/dev/null \
            | sed -E 's/^.. //' \
            | head -n 25 \
            | jq -R . \
            | jq -s . 2>/dev/null || echo '[]'
        )

        echo "⚠️ Git: Working tree dirty (files=${GIT_DIRTY_COUNT})" >> "$LOG_FILE"
        ISSUES+=("Git working tree has uncommitted changes")
    fi
else
    echo "⚠️ Git: Not a git repo" >> "$LOG_FILE"
    ISSUES+=("Site git repo missing: $SITE_REPO")
fi

# 3. Reddit data
REDDIT_FILES=$(find "$WORKSPACE/data/reddit" -name "*.json" 2>/dev/null | wc -l)
if [ "$REDDIT_FILES" -gt 0 ]; then
    echo "✅ Reddit: $REDDIT_FILES files" >> "$LOG_FILE"
else
    echo "⚠️ Reddit: No data files" >> "$LOG_FILE"
fi

# 4. Disk
DISK_PCT=$(df -h "$WORKSPACE" | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_PCT" -lt 80 ]; then
    echo "✅ Disk: ${DISK_PCT}%" >> "$LOG_FILE"
else
    echo "⚠️ Disk: ${DISK_PCT}%" >> "$LOG_FILE"
    ISSUES+=("Disk usage high: ${DISK_PCT}%")
fi

# 5. Memory
FREE_MEM=$(free -m | awk 'NR==2{print $7}')
if [ "$FREE_MEM" -gt 500 ]; then
    echo "✅ Memory: ${FREE_MEM}MB free" >> "$LOG_FILE"
else
    echo "⚠️ Memory: ${FREE_MEM}MB free" >> "$LOG_FILE"
fi

# 6. SEO pages (single source of truth)
SEO_COUNT=$(SITE_DIR="$SITE_REPO" bash "$WORKSPACE/scripts/seo-count.sh" 2>/dev/null | tr -d ' ' || echo 0)
SEO_META=$(SITE_DIR="$SITE_REPO" bash "$WORKSPACE/scripts/seo-count.sh" --json 2>/dev/null || echo '{}')
echo "📊 SEO: $SEO_COUNT pages (method=$(echo "$SEO_META" | jq -r '.method // "unknown"'))" >> "$LOG_FILE"

# 6b. HTML SEO basics audit (title/description/canonical/h1)
HTML_AUDIT_JSON=$(SITE_DIR="$SITE_REPO" bash "$WORKSPACE/scripts/html-seo-audit.sh" --json 2>/dev/null || true)
if [ -z "$HTML_AUDIT_JSON" ]; then
    HTML_AUDIT_JSON='{}'
fi

if echo "$HTML_AUDIT_JSON" | jq -e . >/dev/null 2>&1; then
    HTML_SEO_ISSUE_COUNT=$(echo "$HTML_AUDIT_JSON" | jq -r '.issue_count // null')

    if [ "$HTML_SEO_ISSUE_COUNT" = "0" ]; then
        HTML_SEO_AUDIT_OK="true"
        echo "✅ HTML SEO: OK" >> "$LOG_FILE"
    else
        HTML_SEO_AUDIT_OK="false"
        echo "⚠️ HTML SEO: issues=${HTML_SEO_ISSUE_COUNT:-?}" >> "$LOG_FILE"
        ISSUES+=("HTML SEO audit: issues=${HTML_SEO_ISSUE_COUNT:-?}")
    fi
else
    echo "⚠️ HTML SEO: audit output not JSON" >> "$LOG_FILE"
    ISSUES+=("HTML SEO audit failed to run")
    HTML_SEO_AUDIT_OK="false"
    HTML_SEO_ISSUE_COUNT="null"
fi

# 6c. Sitemap audit (every published URL resolves locally; robots points to it)
SITEMAP_AUDIT_JSON=$(SITE_DIR="$SITE_REPO" bash "$WORKSPACE/scripts/sitemap-audit.sh" --json 2>/dev/null || true)
if [ -z "$SITEMAP_AUDIT_JSON" ]; then
    SITEMAP_AUDIT_JSON='{}'
fi

if echo "$SITEMAP_AUDIT_JSON" | jq -e . >/dev/null 2>&1; then
    SITEMAP_AUDIT_OK=$(echo "$SITEMAP_AUDIT_JSON" | jq -r '.ok // null')
    SITEMAP_MISSING_COUNT=$(echo "$SITEMAP_AUDIT_JSON" | jq -r '.missing_count // null')
    SITEMAP_EXTRA_COUNT=$(echo "$SITEMAP_AUDIT_JSON" | jq -r '.extra_count // null')

    ROBOTS_POINTS=$(echo "$SITEMAP_AUDIT_JSON" | jq -r '.robots_points // "unknown"')
    if [ "$ROBOTS_POINTS" = "ok" ]; then
        ROBOTS_SITEMAP_OK="true"
    else
        ROBOTS_SITEMAP_OK="false"
    fi

    if [ "$SITEMAP_AUDIT_OK" = "true" ]; then
        echo "✅ Sitemap: OK" >> "$LOG_FILE"
    else
        echo "⚠️ Sitemap: missing=${SITEMAP_MISSING_COUNT:-?} extra=${SITEMAP_EXTRA_COUNT:-?} robots=${ROBOTS_POINTS}" >> "$LOG_FILE"
        ISSUES+=("Sitemap mismatch: missing=${SITEMAP_MISSING_COUNT:-?} extra=${SITEMAP_EXTRA_COUNT:-?}")
        BLOCKERS+=("Sitemap mismatch")
    fi
else
    echo "⚠️ Sitemap: audit output not JSON" >> "$LOG_FILE"
    ISSUES+=("Sitemap audit failed to run")
    SITEMAP_AUDIT_OK="false"
    SITEMAP_MISSING_COUNT="null"
    SITEMAP_EXTRA_COUNT="null"
    ROBOTS_SITEMAP_OK="null"
fi

# 6d. Internal link audit (ensure no broken internal .html hrefs)
LINK_AUDIT_JSON=$(SITE_DIR="$SITE_REPO" python3 "$WORKSPACE/scripts/internal-link-audit.py" --json 2>/dev/null || true)
if [ -z "$LINK_AUDIT_JSON" ]; then
    LINK_AUDIT_JSON='{}'
fi

if echo "$LINK_AUDIT_JSON" | jq -e . >/dev/null 2>&1; then
    INTERNAL_LINK_BROKEN_COUNT=$(echo "$LINK_AUDIT_JSON" | jq -r '.broken_count // null')
    if [ "$INTERNAL_LINK_BROKEN_COUNT" = "0" ]; then
        INTERNAL_LINK_AUDIT_OK="true"
        echo "✅ Internal links: OK" >> "$LOG_FILE"
    else
        INTERNAL_LINK_AUDIT_OK="false"
        echo "⚠️ Internal links: broken=${INTERNAL_LINK_BROKEN_COUNT:-?}" >> "$LOG_FILE"
        ISSUES+=("Internal link audit: broken=${INTERNAL_LINK_BROKEN_COUNT:-?}")
    fi
else
    echo "⚠️ Internal links: audit output not JSON" >> "$LOG_FILE"
    ISSUES+=("Internal link audit failed to run")
    INTERNAL_LINK_AUDIT_OK="false"
    INTERNAL_LINK_BROKEN_COUNT="null"
fi

# 6e. Related-links coverage (ensure every content page has a rule; index.html exempt)
RL_COVERAGE_JSON=$(SITE_DIR="$SITE_REPO" python3 "$WORKSPACE/scripts/related-links-suggest.py" --json 2>/dev/null || true)
if [ -z "$RL_COVERAGE_JSON" ]; then
    RL_COVERAGE_JSON='{}'
fi

if echo "$RL_COVERAGE_JSON" | jq -e . >/dev/null 2>&1; then
    RELATED_LINKS_MISSING_COUNT=$(echo "$RL_COVERAGE_JSON" | jq -r '.missing_count // null')
    RELATED_LINKS_SUGGESTED_COUNT=$(echo "$RL_COVERAGE_JSON" | jq -r '.suggested_count // null')

    if [ "$RELATED_LINKS_MISSING_COUNT" = "0" ]; then
        RELATED_LINKS_COVERAGE_OK="true"
        echo "✅ Related links coverage: OK" >> "$LOG_FILE"
    else
        RELATED_LINKS_COVERAGE_OK="false"
        echo "⚠️ Related links coverage: missing=${RELATED_LINKS_MISSING_COUNT:-?}" >> "$LOG_FILE"
        ISSUES+=("Related-links coverage: missing=${RELATED_LINKS_MISSING_COUNT:-?}")
    fi
else
    echo "⚠️ Related links coverage: output not JSON" >> "$LOG_FILE"
    ISSUES+=("Related-links coverage check failed to run")
    RELATED_LINKS_COVERAGE_OK="false"
    RELATED_LINKS_MISSING_COUNT="null"
    RELATED_LINKS_SUGGESTED_COUNT="null"
fi

# 6f. FAQ JSON-LD audit (ensure FAQPage structured data stays synced)
FAQ_AUDIT_JSON=$(python3 "$WORKSPACE/scripts/faq-jsonld-sync.py" --root "$SITE_REPO" --check --json 2>/dev/null || true)
if [ -z "$FAQ_AUDIT_JSON" ]; then
    FAQ_AUDIT_JSON='{}'
fi

if echo "$FAQ_AUDIT_JSON" | jq -e . >/dev/null 2>&1; then
    FAQ_JSONLD_CHANGED_COUNT=$(echo "$FAQ_AUDIT_JSON" | jq -r '.changed_count // null')
    FAQ_JSONLD_ERROR_COUNT=$(echo "$FAQ_AUDIT_JSON" | jq -r '.error_count // null')

    if [ "$FAQ_JSONLD_ERROR_COUNT" != "0" ] && [ "$FAQ_JSONLD_ERROR_COUNT" != "null" ]; then
        FAQ_JSONLD_AUDIT_OK="false"
        echo "⚠️ FAQ JSON-LD: errors=${FAQ_JSONLD_ERROR_COUNT:-?}" >> "$LOG_FILE"
        ISSUES+=("FAQ JSON-LD audit: errors=${FAQ_JSONLD_ERROR_COUNT:-?}")
    elif [ "$FAQ_JSONLD_CHANGED_COUNT" = "0" ]; then
        FAQ_JSONLD_AUDIT_OK="true"
        echo "✅ FAQ JSON-LD: OK" >> "$LOG_FILE"
    else
        FAQ_JSONLD_AUDIT_OK="false"
        echo "⚠️ FAQ JSON-LD: needs_sync=${FAQ_JSONLD_CHANGED_COUNT:-?}" >> "$LOG_FILE"
        ISSUES+=("FAQ JSON-LD out of sync: needs_sync=${FAQ_JSONLD_CHANGED_COUNT:-?}")
    fi
else
    echo "⚠️ FAQ JSON-LD: audit output not JSON" >> "$LOG_FILE"
    ISSUES+=("FAQ JSON-LD audit failed to run")
    FAQ_JSONLD_AUDIT_OK="false"
    FAQ_JSONLD_CHANGED_COUNT="null"
    FAQ_JSONLD_ERROR_COUNT="null"
fi

# 7. Recent commits
COMMITS_24H=$(git -C "$SITE_REPO" log --since="24 hours ago" --oneline 2>/dev/null | wc -l)
echo "📊 Commits (24h): $COMMITS_24H" >> "$LOG_FILE"

# 8. Pipeline blockers detection (SMARTER REDDIT CHECK)

# Add HTML SEO audit as a blocker signal
if [ "$HTML_SEO_AUDIT_OK" = "false" ]; then
    BLOCKERS+=("HTML SEO issues present")
fi

# Internal link audit blocker signal
if [ "$INTERNAL_LINK_AUDIT_OK" = "false" ]; then
    BLOCKERS+=("Broken internal links")
fi

# Related-links coverage blocker signal
if [ "$RELATED_LINKS_COVERAGE_OK" = "false" ]; then
    BLOCKERS+=("Related-links coverage missing")
fi

# FAQ JSON-LD audit blocker signal
if [ "$FAQ_JSONLD_AUDIT_OK" = "false" ]; then
    BLOCKERS+=("FAQ JSON-LD out of sync")
fi

# Check Reddit telemetry (canonical normalized output)
REDDIT_CANON=$(bash "$WORKSPACE/scripts/reddit-telemetry.sh" 2>/dev/null || true)
if [ -n "$REDDIT_CANON" ] && [ -f "$REDDIT_CANON" ]; then
    REDDIT_STATUS=$(jq -r '.status // "UNKNOWN"' "$REDDIT_CANON")
    REDDIT_FRESH=$(jq -r '.fresh // false' "$REDDIT_CANON")
    REDDIT_AGE=$(jq -r '.age_seconds // null' "$REDDIT_CANON")
    KARMA_TOTAL=$(jq -r '.karma.total // null' "$REDDIT_CANON")
    # NOTE: jq's `//` treats `false` as a fallback trigger, so don't use it for booleans
    # where `false` is a valid value.
    KARMA_STALE=$(jq -r 'if .karma.stale == null then true else .karma.stale end' "$REDDIT_CANON")

    if [ "$REDDIT_FRESH" != "true" ]; then
        BLOCKERS+=("Reddit telemetry stale")
        echo "🟠 Reddit: $REDDIT_STATUS (stale; age_s=$REDDIT_AGE)" >> "$LOG_FILE"
    elif [ "$REDDIT_STATUS" = "DEGRADED" ] || [ "$REDDIT_STATUS" = "DOWN" ]; then
        BLOCKERS+=("Reddit API degraded - check scripts")
        echo "🔴 Reddit: $REDDIT_STATUS (age_s=$REDDIT_AGE)" >> "$LOG_FILE"
    else
        echo "✅ Reddit: $REDDIT_STATUS (age_s=$REDDIT_AGE)" >> "$LOG_FILE"
    fi
else
    echo "⚪ Reddit: Not tested" >> "$LOG_FILE"
fi

# Check Twitter credential status
TWITTER_DOC="$WORKSPACE/docs/growth-experiments.md"
if grep -q "🔴.*Twitter" "$TWITTER_DOC" 2>/dev/null; then
    BLOCKERS+=("Twitter blocked - needs API key or browser")
fi

# 9. SEO page growth trend
SEO_GROWTH=$((SEO_COUNT - 10))  # Baseline was 10
echo "📊 SEO growth: +$SEO_GROWTH pages" >> "$LOG_FILE"

echo "=== End Health Check ===" >> "$LOG_FILE"

# Write status JSON
cat > "$STATUS_FILE" << EOF
{
  "last_check": "$(date -Iseconds)",
  "site_repo_path": "$SITE_REPO",
  "site_status": $SITE_CODE,
  "git_today": $(if [ "${GIT_PUSHED_TODAY:-false}" = "true" ] || [ "${GIT_PUSHED_TODAY:-false}" = true ]; then echo true; else echo false; fi),
  "git_sync_ok": $(if [ "${GIT_SYNC_OK:-false}" = "true" ] || [ "${GIT_SYNC_OK:-false}" = true ]; then echo true; else echo false; fi),
  "git_upstream": "${GIT_UPSTREAM}",
  "git_upstream_date": "${GIT_UPSTREAM_DATE}",
  "git_ahead": ${GIT_AHEAD:-0},
  "git_behind": ${GIT_BEHIND:-0},
  "git_dirty": $(if [ "${GIT_DIRTY:-false}" = "true" ] || [ "${GIT_DIRTY:-false}" = true ]; then echo true; else echo false; fi),
  "git_dirty_count": ${GIT_DIRTY_COUNT:-0},
  "git_dirty_files": ${GIT_DIRTY_FILES_JSON:-[]},
  "seo_pages": $SEO_COUNT,
  "html_seo_audit_ok": $HTML_SEO_AUDIT_OK,
  "html_seo_issue_count": $HTML_SEO_ISSUE_COUNT,
  "sitemap_audit_ok": $SITEMAP_AUDIT_OK,
  "sitemap_missing_count": $SITEMAP_MISSING_COUNT,
  "sitemap_extra_count": $SITEMAP_EXTRA_COUNT,
  "robots_sitemap_ok": $ROBOTS_SITEMAP_OK,
  "internal_link_audit_ok": $INTERNAL_LINK_AUDIT_OK,
  "internal_link_broken_count": $INTERNAL_LINK_BROKEN_COUNT,
  "related_links_coverage_ok": $RELATED_LINKS_COVERAGE_OK,
  "related_links_missing_count": $RELATED_LINKS_MISSING_COUNT,
  "related_links_suggested_count": $RELATED_LINKS_SUGGESTED_COUNT,
  "faq_jsonld_audit_ok": $FAQ_JSONLD_AUDIT_OK,
  "faq_jsonld_changed_count": $FAQ_JSONLD_CHANGED_COUNT,
  "faq_jsonld_error_count": $FAQ_JSONLD_ERROR_COUNT,
  "reddit_status": "${REDDIT_STATUS}",
  "reddit_fresh": $REDDIT_FRESH,
  "reddit_age_seconds": $REDDIT_AGE,
  "karma_total": $KARMA_TOTAL,
  "karma_stale": $KARMA_STALE,
  "commits_24h": $COMMITS_24H,
  "disk_pct": $DISK_PCT,
  "memory_free_mb": $FREE_MEM,
  "issues": $({ if [ ${#ISSUES[@]} -gt 0 ]; then printf '%s\n' "${ISSUES[@]}" | jq -R . | jq -s .; else echo '[]'; fi; }),
  "blockers": $({ if [ ${#BLOCKERS[@]} -gt 0 ]; then printf '%s\n' "${BLOCKERS[@]}" | jq -R . | jq -s .; else echo '[]'; fi; })
}
EOF

# Also update canonical system status file used by dashboards
SYSTEMS_FILE="$WORKSPACE/data/status/systems.json"
mkdir -p "$(dirname "$SYSTEMS_FILE")"

# Refresh repo-state fields from the deployable repository, not the workspace
# wrapper repository.
SITE_REPO_BRANCH="UNKNOWN"
SITE_REPO_DETACHED=false
if git -C "$SITE_REPO" rev-parse --git-dir >/dev/null 2>&1; then
  SITE_REPO_BRANCH="$(git -C "$SITE_REPO" rev-parse --abbrev-ref HEAD 2>/dev/null || echo UNKNOWN)"
  if [ "$SITE_REPO_BRANCH" = "HEAD" ]; then
    SITE_REPO_DETACHED=true
    SITE_REPO_BRANCH="DETACHED"
  fi
fi

# Preserve keys owned by other jobs while replacing every health-owned value
# from the just-written status document in one atomic update.
if [ ! -f "$SYSTEMS_FILE" ]; then echo '{}' > "$SYSTEMS_FILE"; fi
jq \
  --slurpfile health "$STATUS_FILE" \
  --arg site_repo_path "$SITE_REPO" \
  --arg site_repo_branch "$SITE_REPO_BRANCH" \
  --argjson site_repo_detached "$SITE_REPO_DETACHED" \
  --argjson site_repo_dirty "$GIT_DIRTY" \
  '. as $existing | $health[0] as $h
   | .last_check=$h.last_check
   | .site_status=$h.site_status
   | .reddit=($h.reddit_status | ascii_downcase)
   | .reddit_fresh=$h.reddit_fresh
   | .reddit_age_seconds=$h.reddit_age_seconds
   | .karma_total=$h.karma_total
   | .karma_stale=$h.karma_stale
   | .seo_pages=$h.seo_pages
   | .html_seo_audit_ok=$h.html_seo_audit_ok
   | .html_seo_issue_count=$h.html_seo_issue_count
   | .sitemap_audit_ok=$h.sitemap_audit_ok
   | .sitemap_missing_count=$h.sitemap_missing_count
   | .sitemap_extra_count=$h.sitemap_extra_count
   | .robots_sitemap_ok=$h.robots_sitemap_ok
   | .internal_link_audit_ok=$h.internal_link_audit_ok
   | .internal_link_broken_count=$h.internal_link_broken_count
   | .related_links_coverage_ok=$h.related_links_coverage_ok
   | .related_links_missing_count=$h.related_links_missing_count
   | .related_links_suggested_count=$h.related_links_suggested_count
   | .faq_jsonld_audit_ok=$h.faq_jsonld_audit_ok
   | .faq_jsonld_changed_count=$h.faq_jsonld_changed_count
   | .faq_jsonld_error_count=$h.faq_jsonld_error_count
   | .site_repo_path=$site_repo_path
   | .site_repo_branch=$site_repo_branch
   | .site_repo_detached=$site_repo_detached
   | .site_repo_dirty=$site_repo_dirty
   | .site_repo_upstream=$h.git_upstream
   | .site_repo_upstream_date=$h.git_upstream_date
   | .site_repo_ahead=$h.git_ahead
   | .site_repo_behind=$h.git_behind
   | .site_repo_sync_ok=$h.git_sync_ok
   | .issues=$h.issues
   | .blockers=$h.blockers' \
  "$SYSTEMS_FILE" > "$SYSTEMS_FILE.tmp" && mv "$SYSTEMS_FILE.tmp" "$SYSTEMS_FILE"

# Alert if issues found
if [ ${#ISSUES[@]} -gt 0 ]; then
    echo ""
    echo "⚠️ ISSUES FOUND:"
    for issue in "${ISSUES[@]}"; do
        echo "  - $issue"
    done
else
    echo ""
    echo "✅ All checks passed"
fi

echo ""
echo "Log: $LOG_FILE"
echo "Status: $STATUS_FILE"
