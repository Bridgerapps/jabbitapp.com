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

# 6. SEO pages
SEO_COUNT=$(find "$WORKSPACE" -maxdepth 1 -name "glp1-*.html" 2>/dev/null | wc -l)
echo "📊 SEO: $SEO_COUNT pages" >> "$LOG_FILE"

# 7. Recent commits
COMMITS_24H=$(git -C "$WORKSPACE" log --since="24 hours ago" --oneline 2>/dev/null | wc -l)
echo "📊 Commits (24h): $COMMITS_24H" >> "$LOG_FILE"

# 8. Pipeline health (check for stalled processes)
STALLED=0
# Add more checks as needed

echo "=== End Health Check ===" >> "$LOG_FILE"

# Write status JSON
cat > "$STATUS_FILE" << EOF
{
  "last_check": "$(date -Iseconds)",
  "site_status": $SITE_CODE,
  "git_today": $([ "$LAST_PUSH" = "$TODAY" ] && echo "true" || echo "false"),
  "seo_pages": $SEO_COUNT,
  "commits_24h": $COMMITS_24H,
  "disk_pct": $DISK_PCT,
  "memory_free_mb": $FREE_MEM,
  "issues": $(printf '%s\n' "${ISSUES[@]}" | jq -R . | jq -s .)
}
EOF

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
