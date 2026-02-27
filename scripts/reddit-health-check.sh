#!/usr/bin/env bash
# Reddit API Health Monitor (cookie+proxy aware)
# Uses the same access path as warmup/comment scripts to avoid false DEGRADED from public 403s.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="${WS:-$SCRIPT_DIR/..}"
LOG_DIR="$WS/data/reddit"
SESSION_FILE="$WS/.reddit-session"

mkdir -p "$LOG_DIR"

# Optional proxy/session (same as runtime scripts)
if [ -f "$WS/scripts/proxy.env" ]; then
  # shellcheck disable=SC1090
  source "$WS/scripts/proxy.env"
fi

COOKIE=""
if [ -f "$SESSION_FILE" ]; then
  COOKIE="$(tr -d '[:space:]' < "$SESSION_FILE")"
fi

UA='Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'
# Match active engagement targets to avoid false negatives from unrelated subreddits.
TEST_SUBS=("Mounjaro" "Ozempic" "Zepbound")
RESULTS=()
STATUS="WORKING"

for sub in "${TEST_SUBS[@]}"; do
  curl_args=(
    -s
    -o /tmp/reddit-health-body.json
    -w "%{http_code}"
    -H "User-Agent: $UA"
    --max-time 30
    "https://www.reddit.com/r/$sub/new.json?limit=1"
  )

  if [ -n "${REDDIT_PROXY_URL:-}" ]; then
    curl_args=( -x "$REDDIT_PROXY_URL" "${curl_args[@]}" )
  fi
  if [ -n "$COOKIE" ]; then
    curl_args=( -H "Cookie: reddit_session=${COOKIE}" "${curl_args[@]}" )
  fi

  HTTP_CODE="$(curl "${curl_args[@]}" 2>/dev/null || echo 000)"

  case "$HTTP_CODE" in
    200)
      RESULTS+=("$sub:200")
      ;;
    429)
      RESULTS+=("$sub:429(RateLimited)")
      STATUS="RATE_LIMITED"
      ;;
    302)
      RESULTS+=("$sub:302(Redirect)")
      [ "$STATUS" = "WORKING" ] && STATUS="DEGRADED"
      ;;
    403)
      RESULTS+=("$sub:403")
      [ "$STATUS" = "WORKING" ] && STATUS="DEGRADED"
      ;;
    *)
      RESULTS+=("$sub:$HTTP_CODE")
      [ "$STATUS" = "WORKING" ] && STATUS="DEGRADED"
      ;;
  esac

done

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
cat > "$LOG_DIR/reddit-health.json" << EOF
{
  "timestamp": "$TIMESTAMP",
  "status": "$STATUS",
  "checks": [$(printf '"%s", ' "${RESULTS[@]}" | sed 's/, $//')]
}
EOF

echo "=== Reddit Health Check ==="
echo "Status: $STATUS"
printf "Checks: %s\n" "${RESULTS[@]}"
echo "Log: $LOG_DIR/reddit-health.json"
