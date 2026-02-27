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

# Also clean files based on filename date extraction (fallback for touched files)
# Files like engagement_queue_20260224_230001.json should be cleaned even if mtime was updated
filename_cleaned=0
for file in "$DATA_DIR"/*queue_*.json "$DATA_DIR"/engagement_*.json "$DATA_DIR"/results_*.json; do
    if [ -f "$file" ]; then
        # Extract date from filename (e.g., engagement_queue_20260224_230001.json -> 20260224)
        filename=$(basename "$file")
        date_match=$(echo "$filename" | grep -oE '[0-9]{8}' | head -1)
        if [ -n "$date_match" ]; then
            file_date=$(date -d "${date_match}" +%s 2>/dev/null) || continue
            today=$(date +%s)
            days_diff=$(( (today - file_date) / 86400 ))
            if [ "$days_diff" -ge 1 ]; then
                rm -f "$file"
                ((filename_cleaned++)) || true
            fi
        fi
    fi
done
if [ "$filename_cleaned" -gt 0 ]; then
    echo "Removed: $filename_cleaned files based on filename date"
fi

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
