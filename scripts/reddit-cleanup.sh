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
CLASSIFY_COUNT=$(find "$DATA_DIR" -name "classify_queue_*.json" -mmin +${RETENTION_MMINS} -type f 2>/dev/null | wc -l)
find "$DATA_DIR" -name "classify_queue_*.json" -mmin +${RETENTION_MMINS} -type f -delete 2>/dev/null
echo "Removed: $CLASSIFY_COUNT old classify queues"

# Find and remove old results files (kept for 7 days for analysis)
RESULTS_DAYS=7
RESULTS_MMINS=$((RESULTS_DAYS * 1440))
RESULTS_COUNT=$(find "$DATA_DIR" -name "results_*.json" -mmin +${RESULTS_MMINS} -type f 2>/dev/null | wc -l)
find "$DATA_DIR" -name "results_*.json" -mmin +${RESULTS_MMINS} -type f -delete 2>/dev/null
echo "Removed: $RESULTS_COUNT old results files (kept 7 days)"

# Find and remove old raw posts (kept for 48h)
RAW_DAYS=2
RAW_MMINS=$((RAW_DAYS * 1440))
RAW_COUNT=$(find "$DATA_DIR" -name "posts_*.json" -mmin +${RAW_MMINS} -type f 2>/dev/null | wc -l)
find "$DATA_DIR" -name "posts_*.json" -mmin +${RAW_MMINS} -type f -delete 2>/dev/null
echo "Removed: $RAW_COUNT old raw posts (kept 48h)"

# Find and remove old engagement files (kept for 3 days)
ENG_DAYS=3
ENG_MMINS=$((ENG_DAYS * 1440))
ENG_COUNT=$(find "$DATA_DIR" -name "engagement_*.json" -mmin +${ENG_MMINS} -type f 2>/dev/null | wc -l)
find "$DATA_DIR" -name "engagement_*.json" -mmin +${ENG_MMINS} -type f -delete 2>/dev/null
echo "Removed: $ENG_COUNT old engagement files"

# Count files after
AFTER=$(find "$DATA_DIR" -name "*.json" -type f | wc -l)
echo ""
echo "Files after: $AFTER"
echo "Total removed: $((BEFORE - AFTER))"

# Show disk space saved
SAVED=$(du -sh "$DATA_DIR" 2>/dev/null | cut -f1)
echo "Disk usage: $SAVED"

echo "=== Cleanup Complete ==="
