#!/usr/bin/env bash
# Reddit Ladder Warmup Parameters
# Controls karma-building cadence and Jabbit mention permissions

# Warmup started: 2026-02-21
# Day 1-7: Pure warmup (no mentions)
# Day 8+: Subtle mentions allowed (only in relevant contexts, 1 in 4 chance, never promotional)
# The mention style you wanted: "I use Jabbit..." not "You should use Jabbit..."

# Load runtime identity/settings if present so standalone calls are consistent.
WS="/home/jabbit/.openclaw/workspace"
if [ -f "$WS/scripts/reddit.env" ]; then
  # shellcheck disable=SC1090
  source "$WS/scripts/reddit.env"
fi

REDDIT_WARMUP_START="${REDDIT_WARMUP_START:-2026-02-27}"
export REDDIT_WARMUP_START

# Calculate current warmup day
WARMUP_START_TS=$(date -d "$REDDIT_WARMUP_START" +%s 2>/dev/null || echo 0)
NOW_TS=$(date +%s)
DAYS_SINCE_START=$(( (NOW_TS - WARMUP_START_TS) / 86400 ))
export REDDIT_WARMUP_DAY=$((DAYS_SINCE_START + 1))

# Comment limits by warmup day
if [ "$REDDIT_WARMUP_DAY" -le 7 ]; then
    MAX_UPVOTES=2
    MAX_COMMENTS=1
    JABBIT_MENTION_ALLOWED=false
elif [ "$REDDIT_WARMUP_DAY" -le 14 ]; then
    MAX_UPVOTES=5
    MAX_COMMENTS=2
    JABBIT_MENTION_ALLOWED=subtle
else
    MAX_UPVOTES=10
    MAX_COMMENTS=4
    JABBIT_MENTION_ALLOWED=subtle
fi

# Cycle slot (0-2 for 8h intervals)
HOUR=${HOUR:-$(date +%H)}
# Force decimal interpretation to avoid octal issues with 08/09
SLOT=$(( (10#$HOUR / 8) % 3 ))
export REDDIT_CYCLE_SLOT=$SLOT

export MAX_UPVOTES
export MAX_COMMENTS
export JABBIT_MENTION_ALLOWED

if [ "${1:-}" = "env" ]; then
    echo "export REDDIT_WARMUP_DAY=$REDDIT_WARMUP_DAY"
    echo "export REDDIT_CYCLE_SLOT=$REDDIT_CYCLE_SLOT"
    echo "export MAX_UPVOTES=$MAX_UPVOTES"
    echo "export MAX_COMMENTS=$MAX_COMMENTS"
    echo "export JABBIT_MENTION_ALLOWED=$JABBIT_MENTION_ALLOWED"
fi
