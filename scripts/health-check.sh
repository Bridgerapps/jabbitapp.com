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

# Defaults so JSON always has stable keys
REDDIT_STATUS="UNKNOWN"
REDDIT_FRESH="false"
REDDIT_AGE="null"
KARMA_TOTAL="null"
KARMA_STALE="true"

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

# 7. Recent commits
COMMITS_24H=$(git -C "$WORKSPACE" log --since="24 hours ago" --oneline 2>/dev/null | wc -l)
echo "📊 Commits (24h): $COMMITS_24H" >> "$LOG_FILE"

# 8. Pipeline blockers detection (SMARTER REDDIT CHECK)
BLOCKERS=()

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
  "reddit_status": "${REDDIT_STATUS}",
  "reddit_fresh": $REDDIT_FRESH,
  "reddit_age_seconds": $REDDIT_AGE,
  "karma_total": $KARMA_TOTAL,
  "karma_stale": $KARMA_STALE,
  "commits_24h": $COMMITS_24H,
  "disk_pct": $DISK_PCT,
  "memory_free_mb": $FREE_MEM,
  "issues": $(printf '%s\n' "${ISSUES[@]}" | jq -R . | jq -s .),
  "blockers": $(printf '%s\n' "${BLOCKERS[@]}" | jq -R . | jq -s .)
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
    --argjson karma_total "$KARMA_TOTAL" \
    --argjson karma_stale "$KARMA_STALE" \
    '.last_check=$last_check
     | .reddit=$reddit
     | .reddit_fresh=$reddit_fresh
     | .reddit_age_seconds=$reddit_age_seconds
     | .seo_pages=$seo_pages
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
    --argjson karma_total "$KARMA_TOTAL" \
    --argjson karma_stale "$KARMA_STALE" \
    '{last_check:$last_check, reddit:$reddit, reddit_fresh:$reddit_fresh, reddit_age_seconds:$reddit_age_seconds, seo_pages:$seo_pages, karma_total:$karma_total, karma_stale:$karma_stale}' \
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
