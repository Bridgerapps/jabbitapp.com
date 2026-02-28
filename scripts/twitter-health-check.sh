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

# --- Late.com / Twitter API best-effort tests ---
if [ -n "${LATE_API_KEY:-}" ]; then
  echo ""
  echo "Test 1: Twitter API via Late key (counts endpoint)"
  RESULT1=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $LATE_API_KEY" \
    "https://api.twitter.com/2/tweets/counts/recent" 2>/dev/null || true)
  if [ "$RESULT1" = "200" ]; then
    echo "✅ Late lane: WORKING (HTTP $RESULT1)"
    LATE_OK=true
  else
    echo "❌ Late lane: BLOCKED/FAIL (HTTP ${RESULT1:-000})"
  fi

  echo ""
  echo "Test 2: Twitter API via Late key (users/me endpoint)"
  RESULT2=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $LATE_API_KEY" \
    "https://api.twitter.com/2/users/me" 2>/dev/null || true)
  if [ "$RESULT2" = "200" ]; then
    echo "✅ users/me: WORKING (HTTP $RESULT2)"
    LATE_OK=true
  else
    echo "❌ users/me: BLOCKED/FAIL (HTTP ${RESULT2:-000})"
  fi

  echo ""
  echo "Test 3: Detect HTML/JS challenge (content-type check)"
  RESULT3=$(curl -s -w "%{content_type}" -o /dev/null -H "Authorization: Bearer $LATE_API_KEY" \
    "https://api.twitter.com/2/tweets/counts/recent" 2>/dev/null || true)
  if echo "$RESULT3" | grep -q "text/html"; then
    echo "⚠️  JS/HTML challenge detected (likely automation blocked)"
  else
    echo "✅ No HTML challenge detected (or request failed in another way)"
  fi
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
