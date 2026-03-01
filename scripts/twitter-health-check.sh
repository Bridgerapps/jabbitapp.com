#!/usr/bin/env bash
# Twitter Health Check (key-aware)
#
# Goal:
# - Report whether distribution via Twitter is *configured*.
# - Best-effort test the Late.com → Twitter API lane when LATE_API_KEY is present.
# - Avoid false failures when Late is intentionally not configured.
#
# Usage:
#   bash scripts/twitter-health-check.sh

set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"

# Optional local env (do NOT commit secrets here; keep as local-only file).
# If present, load it with export semantics.
if [ -f "$WS/scripts/twitter.env" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$WS/scripts/twitter.env"
  set +a
fi

# Back-compat alias: older scripts used TWITTERAPI_KEY.
: "${TWITTER_API_KEY:=${TWITTERAPI_KEY:-}}"

echo "=== Twitter Health Check ==="
echo "Time: $(date -Iseconds)"
echo ""

LATE_OK=false
TWAPI_OK=false

# --- Config status ---
if [ -n "${LATE_API_KEY:-}" ]; then
  echo "✅ LATE_API_KEY is set (Late.com lane enabled)"
else
  echo "⚠️  LATE_API_KEY not set (Late.com lane disabled)"
fi

if [ -n "${TWITTER_API_KEY:-}" ]; then
  echo "✅ TWITTER_API_KEY is set (TwitterAPI.io lane configured)"
else
  echo "⚠️  TWITTER_API_KEY not set (TwitterAPI.io lane not configured)"
fi

# --- Late.com lane (Late API) best-effort tests ---
# Late API keys authenticate against Late's API — they are NOT Twitter bearer tokens.
# So we test Late's API directly (not api.twitter.com).
if [ -n "${LATE_API_KEY:-}" ]; then
  echo ""
  echo "Test 1: Late API /v1/me (auth + JSON response)"

  BODY_FILE="$(mktemp)"
  HTTP_CODE=$(curl -s -o "$BODY_FILE" -w "%{http_code}" \
    -H "Authorization: Bearer $LATE_API_KEY" \
    --max-time 30 \
    "https://late.com/api/v1/me" 2>/dev/null || echo 000)

  CONTENT_TYPE=$(curl -s -o /dev/null -w "%{content_type}" \
    -H "Authorization: Bearer $LATE_API_KEY" \
    --max-time 30 \
    "https://late.com/api/v1/me" 2>/dev/null || true)

  if [ "$HTTP_CODE" = "200" ] && echo "$CONTENT_TYPE" | grep -qi "application/json"; then
    echo "✅ Late lane: WORKING (HTTP 200, JSON)"
    LATE_OK=true
  else
    if echo "$CONTENT_TYPE" | grep -qi "text/html"; then
      echo "❌ Late lane: BLOCKED (HTML/JS challenge likely; HTTP ${HTTP_CODE:-000})"
    else
      echo "❌ Late lane: FAIL (HTTP ${HTTP_CODE:-000}; content-type: ${CONTENT_TYPE:-unknown})"
    fi
  fi

  rm -f "$BODY_FILE" >/dev/null 2>&1 || true
fi

# --- TwitterAPI.io lane ---
# NOTE: We do not run an authenticated “write” test here (posting).
# If you want to validate posting, use scripts/twitter-api-io-post.sh with an explicit message.
if [ -n "${TWITTER_API_KEY:-}" ]; then
  TWAPI_OK=true
fi

# --- Summary ---
echo ""
echo "=== Summary ==="
if [ "$LATE_OK" = true ] || [ "$TWAPI_OK" = true ]; then
  echo "✅ Twitter distribution is at least partially configured"
  if [ "$LATE_OK" != true ]; then
    echo "  - Late lane is not confirmed working (often blocked by Cloudflare/JS)."
  fi
  if [ "$TWAPI_OK" = true ]; then
    echo "  - TwitterAPI.io key is present (posting should work via scripts/twitter-api-io-post.sh)."
  fi
  exit 0
fi

echo "❌ Twitter distribution not configured (no working lane detected)"
echo ""
echo "Next steps:"
echo "- See docs/runbooks/twitter.md"
exit 1
