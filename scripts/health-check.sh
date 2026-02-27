#!/bin/bash
# Health check script for Jabbit - runs in cron
# Checks: site, github sync, reddit data, disk, memory, recent commits

WORKSPACE="/home/jabbit/.openclaw/workspace"
LOG_FILE="$WORKSPACE/logs/health-$(date +%Y-%m-%d).log"

echo "=== Health Check $(date) ===" >> "$LOG_FILE"

# 1. Site health
if curl -s -o /dev/null -w "%{http_code}" https://www.jabbitapp.com | grep -q "200"; then
    echo "✅ Site: HTTP 200" >> "$LOG_FILE"
else
    echo "❌ Site: DOWN" >> "$LOG_FILE"
fi

# 2. Git sync - check if pushed today
LAST_PUSH=$(git -C "$WORKSPACE" log -1 --format=%cd --date=format:%Y-%m-%d 2>/dev/null)
TODAY=$(date +%Y-%m-%d)
if [ "$LAST_PUSH" = "$TODAY" ]; then
    echo "✅ Git: Pushed today" >> "$LOG_FILE"
else
    echo "⚠️ Git: Last push $LAST_PUSH" >> "$LOG_FILE"
fi

# 3. Reddit data
REDDIT_FILES=$(find "$WORKSPACE" -path "*/reddit*" -name "*.json" 2>/dev/null | wc -l)
if [ "$REDDIT_FILES" -gt 1000 ]; then
    echo "✅ Reddit: $REDDIT_FILES files" >> "$LOG_FILE"
else
    echo "⚠️ Reddit: Only $REDDIT_FILES files" >> "$LOG_FILE"
fi

# 4. Disk
DISK_PCT=$(df -h "$WORKSPACE" | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_PCT" -lt 80 ]; then
    echo "✅ Disk: ${DISK_PCT}%" >> "$LOG_FILE"
else
    echo "⚠️ Disk: ${DISK_PCT}%" >> "$LOG_FILE"
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

echo "=== End Health Check ===" >> "$LOG_FILE"

# Output summary
echo "Health check complete. Last run:"
tail -10 "$LOG_FILE"
