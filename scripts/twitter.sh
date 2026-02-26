#!/usr/bin/env bash
# Unified Twitter script

ACTION="${1:-status}"

case "$ACTION" in
  post) bash ~/.openclaw/workspace/scripts/twitter-api-io-post.sh ;;
  test) bash ~/.openclaw/workspace/scripts/twitter-browser-test.sh ;;
  health|status) bash ~/.openclaw/workspace/scripts/twitter-health-check.sh ;;
  resolve) bash ~/.openclaw/workspace/scripts/twitter-resolution.sh ;;
  *) bash ~/.openclaw/workspace/scripts/twitter-unified.sh "$@" ;;
esac
