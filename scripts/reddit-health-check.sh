#!/usr/bin/env bash
# Reddit Public Health Monitor (NO AUTH)
# Policy: must never read .reddit-session or send Cookie headers.
# Purpose: detect general availability / rate limiting for discovery paths.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="${WS:-$SCRIPT_DIR/..}"
LOG_DIR="$WS/data/reddit"
mkdir -p "$LOG_DIR"

# Load proxy config when present. This file contains infrastructure details,
# but never Reddit credentials or cookies.
if [ -f "$WS/scripts/proxy.env" ]; then
  # shellcheck disable=SC1090
  source "$WS/scripts/proxy.env" 2>/dev/null || true
fi

UA='OpenClawRedditMonitor/1.0 (public availability check; contact: jabbitapp.com)'
TARGETS=("Mounjaro" "Ozempic" "Zepbound")
TARGET_LABEL="$(IFS=+; printf '%s' "${TARGETS[*]}")"
FEED_URL="https://www.reddit.com/r/${TARGET_LABEL}/new/.rss?limit=3"
DISCOVERY_PROXY="${DISCOVERY_REDDIT_PROXY_URL:-${REDDIT_PROXY_URL:-}}"

body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT

fetch_feed() {
  local proxy="${1:-}"
  local -a args=(
    -sS
    -o "$body_file"
    -w '%{http_code}'
    -A "$UA"
    -H 'Accept: application/atom+xml, application/xml;q=0.9'
    --connect-timeout 5
    --max-time 20
  )
  if [ -n "$proxy" ]; then
    args=(-x "$proxy" "${args[@]}")
  fi

  local code
  code="$(curl "${args[@]}" "$FEED_URL" 2>/dev/null)" || true
  case "$code" in
    [0-9][0-9][0-9]) printf '%s' "$code" ;;
    *) printf '000' ;;
  esac
}

feed_valid() {
  [ "$1" = "200" ] && grep -Eq '<feed([[:space:]>])' "$body_file"
}

# One public multireddit request checks the discovery transport without
# triggering the anonymous rate limit with back-to-back subreddit probes.
HTTP_CODE="$(fetch_feed)"
SOURCE="none"
STATUS="DOWN"
if feed_valid "$HTTP_CODE"; then
  SOURCE="rss-direct"
  STATUS="WORKING"
elif [ -n "$DISCOVERY_PROXY" ]; then
  # Retry the same public feed through the configured discovery proxy only
  # when the direct request fails. No auth or Cookie header is ever used.
  HTTP_CODE="$(fetch_feed "$DISCOVERY_PROXY")"
  if feed_valid "$HTTP_CODE"; then
    SOURCE="rss-proxy"
    STATUS="WORKING"
  fi
fi

if [ "$STATUS" = "WORKING" ]; then
  CHECK="${TARGET_LABEL}:200(${SOURCE})"
  TRANSPORT="rss"
else
  CHECK="${TARGET_LABEL}:unavailable(rss=${HTTP_CODE})"
  TRANSPORT="none"
fi

TIMESTAMP="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
TARGETS_JSON="$(printf '%s\n' "${TARGETS[@]}" | jq -R . | jq -s .)"

jq -n \
  --arg timestamp "$TIMESTAMP" \
  --arg status "$STATUS" \
  --arg transport "$TRANSPORT" \
  --arg source "$SOURCE" \
  --arg feed_url "$FEED_URL" \
  --arg http_code "$HTTP_CODE" \
  --arg check "$CHECK" \
  --argjson targets "$TARGETS_JSON" \
  '{timestamp:$timestamp,
    status:$status,
    policy:"public-read-only-no-auth",
    transport:$transport,
    checks:[$check],
    details:[{targets:$targets, ok:($status == "WORKING"), source:$source, rss_http:$http_code, feed_url:$feed_url}]}' \
  > "$LOG_DIR/reddit-health.json"

echo "=== Reddit Health Check (public-only) ==="
echo "Status: $STATUS"
echo "Transport: $TRANSPORT"
echo "Checks: $CHECK"
echo "Log: $LOG_DIR/reddit-health.json"
