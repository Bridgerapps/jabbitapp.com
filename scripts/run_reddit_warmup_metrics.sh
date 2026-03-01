#!/usr/bin/env bash
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"

# jitter (skip when testing)
if [ "${REDDIT_SKIP_JITTER:-0}" != "1" ]; then
  sleep $((RANDOM%900+120))
fi

# ladder + warmup action (best-effort action, metrics always emitted)
eval "$(bash "$WS/scripts/reddit_ladder_params.sh" env)"
MAX_UPVOTES="$MAX_UPVOTES" bash "$WS/scripts/reddit_residential_warmup.sh" >/dev/null 2>&1 || true

python3 "$WS/scripts/reddit_daily_metrics.py"
