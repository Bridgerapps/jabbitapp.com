#!/usr/bin/env bash
# Unified Twitter script

set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"

# Optional local env (local-only file; do not commit secrets)
if [ -f "$WS/scripts/twitter.env" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$WS/scripts/twitter.env"
  set +a
fi

# Back-compat alias
: "${TWITTER_API_KEY:=${TWITTERAPI_KEY:-}}"

ACTION="${1:-status}"

case "$ACTION" in
  post) bash ~/.openclaw/workspace/scripts/twitter-api-io-post.sh ;;
  test) bash ~/.openclaw/workspace/scripts/twitter-browser-test.sh ;;
  health|status) bash ~/.openclaw/workspace/scripts/twitter-health-check.sh ;;
  resolve) bash ~/.openclaw/workspace/scripts/twitter-resolution.sh ;;
  *) bash ~/.openclaw/workspace/scripts/twitter-unified.sh "$@" ;;
esac
