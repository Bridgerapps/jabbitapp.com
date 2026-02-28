#!/bin/bash
# Enhanced Health Check with Alerting
# Checks: site, github sync, reddit data, disk, memory, recent commits, seo pages
# Outputs status and saves to log

WORKSPACE="/home/jabbit/.openclaw/workspace"
LOG_FILE="$WORKSPACE/logs/health-$(date +%Y-%m-%d).log"
STATUS_FILE="$WORKSPACE/data/status/health.json"

mkdir -p "$WORKSPACE/logs"
mkdir -p "$WORKSPACE/data/status"

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
SITE_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://www.jabbitapp.com 2>/dev/null || echo "000")
if [ "$SITE_CODE" = "200" ]; then
    echo "✅ Site: HTTP $SITE_CODE" >> "$LOG_FILE"
else
    echo "❌ Site: HTTP $SITE_CODE" >> "$LOG_FILE"
    ISSUES+=("Site down: HTTP $SITE_CODE")
fi

# 2. Git sync - check if pushed today
LAST_PUSH=$(git -C "$WORKSPACE" log -1 --format=%cd --date=format:%Y-%m-%d 2>/dev/null)
TODAY=$(date +%Y-%m-%d)
if [ "$LAST_PUSH" = "$TODAY" ]; then
    echo "✅ Git: Pushed today" >> "$LOG_FILE"
else
    echo "⚠️ Git: Last push $LAST_PUSH" >> "$LOG_FILE"
    ISSUES+=("Git not pushed today")
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
SEO_COUNT=$(bash "$WORKSPACE/scripts/seo-count.sh" 2>/dev/null | tr -d ' ' || echo 0)
SEO_META=$(bash "$WORKSPACE/scripts/seo-count.sh" --json 2>/dev/null || echo '{}')
echo "📊 SEO: $SEO_COUNT pages (method=$(echo "$SEO_META" | jq -r '.method // "unknown"'))" >> "$LOG_FILE"

# 6b. HTML SEO basics audit (title/description/canonical/h1)
HTML_AUDIT_JSON=$(bash "$WORKSPACE/scripts/html-seo-audit.sh" --json 2>/dev/null || true)
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

# 6c. Sitemap audit (sitemap.xml vs local html)
SITEMAP_AUDIT_JSON=$(bash "$WORKSPACE/scripts/sitemap-audit.sh" --json 2>/dev/null || true)
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
LINK_AUDIT_JSON=$(python3 "$WORKSPACE/scripts/internal-link-audit.py" --json 2>/dev/null || true)
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
RL_COVERAGE_JSON=$(python3 "$WORKSPACE/scripts/related-links-suggest.py" --json 2>/dev/null || true)
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
FAQ_AUDIT_JSON=$(python3 "$WORKSPACE/scripts/faq-jsonld-sync.py" --check --json 2>/dev/null || true)
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
COMMITS_24H=$(git -C "$WORKSPACE" log --since="24 hours ago" --oneline 2>/dev/null | wc -l)
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
    KARMA_STALE=$(jq -r '.karma.stale // true' "$REDDIT_CANON")

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
  "site_status": $SITE_CODE,
  "git_today": $([ "$LAST_PUSH" = "$TODAY" ] && echo "true" || echo "false"),
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

# Preserve existing keys; update the ones this check owns.
if [ -f "$SYSTEMS_FILE" ]; then
  jq \
    --arg last_check "$(date -Iseconds)" \
    --arg reddit "$(echo "$REDDIT_STATUS" | tr '[:upper:]' '[:lower:]')" \
    --argjson reddit_fresh "$REDDIT_FRESH" \
    --argjson reddit_age_seconds "$REDDIT_AGE" \
    --argjson seo_pages "$SEO_COUNT" \
    --argjson html_seo_audit_ok "$HTML_SEO_AUDIT_OK" \
    --argjson html_seo_issue_count "$HTML_SEO_ISSUE_COUNT" \
    --argjson sitemap_audit_ok "$SITEMAP_AUDIT_OK" \
    --argjson sitemap_missing_count "$SITEMAP_MISSING_COUNT" \
    --argjson sitemap_extra_count "$SITEMAP_EXTRA_COUNT" \
    --argjson robots_sitemap_ok "$ROBOTS_SITEMAP_OK" \
    --argjson internal_link_audit_ok "$INTERNAL_LINK_AUDIT_OK" \
    --argjson internal_link_broken_count "$INTERNAL_LINK_BROKEN_COUNT" \
    --argjson related_links_coverage_ok "$RELATED_LINKS_COVERAGE_OK" \
    --argjson related_links_missing_count "$RELATED_LINKS_MISSING_COUNT" \
    --argjson related_links_suggested_count "$RELATED_LINKS_SUGGESTED_COUNT" \
    --argjson faq_jsonld_audit_ok "$FAQ_JSONLD_AUDIT_OK" \
    --argjson faq_jsonld_changed_count "$FAQ_JSONLD_CHANGED_COUNT" \
    --argjson faq_jsonld_error_count "$FAQ_JSONLD_ERROR_COUNT" \
    --argjson karma_total "$KARMA_TOTAL" \
    --argjson karma_stale "$KARMA_STALE" \
    '.last_check=$last_check
     | .reddit=$reddit
     | .reddit_fresh=$reddit_fresh
     | .reddit_age_seconds=$reddit_age_seconds
     | .seo_pages=$seo_pages
     | .html_seo_audit_ok=$html_seo_audit_ok
     | .html_seo_issue_count=$html_seo_issue_count
     | .sitemap_audit_ok=$sitemap_audit_ok
     | .sitemap_missing_count=$sitemap_missing_count
     | .sitemap_extra_count=$sitemap_extra_count
     | .robots_sitemap_ok=$robots_sitemap_ok
     | .internal_link_audit_ok=$internal_link_audit_ok
     | .internal_link_broken_count=$internal_link_broken_count
     | .related_links_coverage_ok=$related_links_coverage_ok
     | .related_links_missing_count=$related_links_missing_count
     | .related_links_suggested_count=$related_links_suggested_count
     | .faq_jsonld_audit_ok=$faq_jsonld_audit_ok
     | .faq_jsonld_changed_count=$faq_jsonld_changed_count
     | .faq_jsonld_error_count=$faq_jsonld_error_count
     | .karma_total=$karma_total
     | .karma_stale=$karma_stale' \
    "$SYSTEMS_FILE" > "$SYSTEMS_FILE.tmp" && mv "$SYSTEMS_FILE.tmp" "$SYSTEMS_FILE"
else
  jq -n \
    --arg last_check "$(date -Iseconds)" \
    --arg reddit "$(echo "$REDDIT_STATUS" | tr '[:upper:]' '[:lower:]')" \
    --argjson reddit_fresh "$REDDIT_FRESH" \
    --argjson reddit_age_seconds "$REDDIT_AGE" \
    --argjson seo_pages "$SEO_COUNT" \
    --argjson html_seo_audit_ok "$HTML_SEO_AUDIT_OK" \
    --argjson html_seo_issue_count "$HTML_SEO_ISSUE_COUNT" \
    --argjson sitemap_audit_ok "$SITEMAP_AUDIT_OK" \
    --argjson sitemap_missing_count "$SITEMAP_MISSING_COUNT" \
    --argjson sitemap_extra_count "$SITEMAP_EXTRA_COUNT" \
    --argjson robots_sitemap_ok "$ROBOTS_SITEMAP_OK" \
    --argjson internal_link_audit_ok "$INTERNAL_LINK_AUDIT_OK" \
    --argjson internal_link_broken_count "$INTERNAL_LINK_BROKEN_COUNT" \
    --argjson related_links_coverage_ok "$RELATED_LINKS_COVERAGE_OK" \
    --argjson related_links_missing_count "$RELATED_LINKS_MISSING_COUNT" \
    --argjson related_links_suggested_count "$RELATED_LINKS_SUGGESTED_COUNT" \
    --argjson faq_jsonld_audit_ok "$FAQ_JSONLD_AUDIT_OK" \
    --argjson faq_jsonld_changed_count "$FAQ_JSONLD_CHANGED_COUNT" \
    --argjson faq_jsonld_error_count "$FAQ_JSONLD_ERROR_COUNT" \
    --argjson karma_total "$KARMA_TOTAL" \
    --argjson karma_stale "$KARMA_STALE" \
    '{last_check:$last_check,
      reddit:$reddit,
      reddit_fresh:$reddit_fresh,
      reddit_age_seconds:$reddit_age_seconds,
      seo_pages:$seo_pages,
      html_seo_audit_ok:$html_seo_audit_ok,
      html_seo_issue_count:$html_seo_issue_count,
      sitemap_audit_ok:$sitemap_audit_ok,
      sitemap_missing_count:$sitemap_missing_count,
      sitemap_extra_count:$sitemap_extra_count,
      robots_sitemap_ok:$robots_sitemap_ok,
      internal_link_audit_ok:$internal_link_audit_ok,
      internal_link_broken_count:$internal_link_broken_count,
      related_links_coverage_ok:$related_links_coverage_ok,
      related_links_missing_count:$related_links_missing_count,
      related_links_suggested_count:$related_links_suggested_count,
      faq_jsonld_audit_ok:$faq_jsonld_audit_ok,
      faq_jsonld_changed_count:$faq_jsonld_changed_count,
      faq_jsonld_error_count:$faq_jsonld_error_count,
      karma_total:$karma_total,
      karma_stale:$karma_stale}' \
    > "$SYSTEMS_FILE"
fi

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
