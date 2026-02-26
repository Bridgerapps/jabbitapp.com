#!/bin/bash
# Reddit Data Cleanup Script
# Removes stale Reddit pipeline data older than 3 days
# Autonomy task: removes repeated manual disk cleanup + fixes mtime bug

set -e

DATA_DIR="/home/jabbit/.openclaw/workspace/data/reddit"
RETENTION_DAYS=1  # Files older than 1 day (using mmin for precision)
# mmin: +N means more than N minutes ago
# 1 day = 1440 minutes, so +1440 catches files > 24 hours old

echo "=== Reddit Data Cleanup ==="
echo "Retention policy: ${RETENTION_DAYS} day(s)"
echo ""

# Count files before
BEFORE=$(find "$DATA_DIR" -name "*.json" -type f | wc -l)
echo "Files before: $BEFORE"

# Calculate minutes for retention (1440 minutes per day)
RETENTION_MMINS=$((RETENTION_DAYS * 1440))

# Find and remove old classify queues (they're large and stale after processing)
# Matches classify_queue_*.json, engagement_queue_*.json, engagement_*.json, and results_*.json
CLASSIFY_COUNT=$(find "$DATA_DIR" \( -name "classify_queue_*.json" -o -name "engagement_queue_*.json" -o -name "engagement_*.json" -o -name "results_*.json" \) -mmin +${RETENTION_MMINS} -type f 2>/dev/null | wc -l)
find "$DATA_DIR" \( -name "classify_queue_*.json" -o -name "engagement_queue_*.json" -o -name "engagement_*.json" -o -name "results_*.json" \) -mmin +${RETENTION_MMINS} -type f -delete 2>/dev/null
echo "Removed: $CLASSIFY_COUNT old classify/engagement/results files"

# Find and remove old raw posts (kept for 48h)
RAW_DAYS=2
RAW_MMINS=$((RAW_DAYS * 1440))
RAW_COUNT=$(find "$DATA_DIR" -name "posts_*.json" -mmin +${RAW_MMINS} -type f 2>/dev/null | wc -l)
find "$DATA_DIR" -name "posts_*.json" -mmin +${RAW_MMINS} -type f -delete 2>/dev/null
echo "Removed: $RAW_COUNT old raw posts (kept 48h)"

# Count files after
AFTER=$(find "$DATA_DIR" -name "*.json" -type f | wc -l)
echo ""
echo "Files after: $AFTER"
echo "Total removed: $((BEFORE - AFTER))"

# Show disk space saved
SAVED=$(du -sh "$DATA_DIR" 2>/dev/null | cut -f1)
echo "Disk usage: $SAVED"

echo "=== Cleanup Complete ==="
