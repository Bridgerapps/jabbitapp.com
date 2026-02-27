#!/bin/bash
# Reddit Data Backup Script
# Backs up Reddit warmup data for recovery

BACKUP_DIR="$HOME/.openclaw/workspace/data/reddit-backups"
DATE=$(date +%Y-%m-%d)

mkdir -p "$BACKUP_DIR"

# Backup reddit warmup state
if [ -f "$HOME/.openclaw/workspace/data/reddit-warmup.json" ]; then
    cp "$HOME/.openclaw/workspace/data/reddit-warmup.json" "$BACKUP_DIR/reddit-warmup-$DATE.json"
    echo "✅ Backed up reddit-warmup.json"
fi

# Backup any karma tracking
if [ -f "$HOME/.openclaw/workspace/data/karma-tracker.json" ]; then
    cp "$HOME/.openclaw/workspace/data/karma-tracker.json" "$BACKUP_DIR/karma-tracker-$DATE.json"
    echo "✅ Backed up karma-tracker.json"
fi

# Backup Reddit credentials (if exists)
if [ -f "$HOME/.openclaw/workspace/data/reddit-creds.enc" ]; then
    cp "$HOME/.openclaw/workspace/data/reddit-creds.enc" "$BACKUP_DIR/reddit-creds-$DATE.enc"
    echo "✅ Backed up reddit-creds.enc"
fi

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "*.json" -mtime +7 -delete 2>/dev/null
find "$BACKUP_DIR" -name "*.enc" -mtime +7 -delete 2>/dev/null

echo "📦 Reddit backup complete: $DATE"
ls -la "$BACKUP_DIR" | tail -5
