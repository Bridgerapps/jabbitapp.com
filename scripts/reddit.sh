#!/usr/bin/env bash
# Unified Reddit script

ACTION="${1:-status}"

case "$ACTION" in
  warmup) bash ~/.openclaw/workspace/scripts/reddit_residential_warmup.sh ;;
  comment) bash ~/.openclaw/workspace/scripts/reddit_direct_comment_once.sh ;;
  health|status) bash ~/.openclaw/workspace/scripts/reddit-health-check.sh ;;
  cleanup) bash ~/.openclaw/workspace/scripts/reddit-cleanup.sh ;;
  params) bash ~/.openclaw/workspace/scripts/reddit_ladder_params.sh "$@" ;;
  *) echo "Usage: $0 {warmup|comment|health|cleanup|params}" ;;
esac
