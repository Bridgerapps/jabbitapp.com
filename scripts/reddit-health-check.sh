#!/usr/bin/env bash
# Reddit Public Health Monitor (NO AUTH)
# Policy: must never read .reddit-session or send Cookie headers.
# Purpose: detect general availability / rate limiting for discovery paths.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="${WS:-$SCRIPT_DIR/..}"
LOG_DIR="$WS/data/reddit"
mkdir -p "$LOG_DIR"

# Optional proxy (discovery only)
if [ -f "$WS/scripts/proxy.env" ]; then
  # shellcheck disable=SC1090
  source "$WS/scripts/proxy.env" 2>/dev/null || true
fi

UA='Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'
TEST_SUBS=("Mounjaro" "Ozempic" "Zepbound")
RESULTS=()
STATUS="WORKING"

DISCOVERY_PROXY="${DISCOVERY_REDDIT_PROXY_URL:-${REDDIT_PROXY_URL:-}}"

for sub in "${TEST_SUBS[@]}"; do
  curl_args=(
    -s
    -o /tmp/reddit-health-body.json
    -w "%{http_code}"
    -H "User-Agent: $UA"
    -H "Accept: application/json"
    --max-time 20
    "https://www.reddit.com/r/$sub/new.json?limit=1&raw_json=1"
  )

  if [ -n "${DISCOVERY_PROXY:-}" ]; then
    curl_args=( -x "$DISCOVERY_PROXY" "${curl_args[@]}" )
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

echo "=== Reddit Health Check (public-only) ==="
echo "Status: $STATUS"
printf "Checks: %s\n" "${RESULTS[@]}"
echo "Log: $LOG_DIR/reddit-health.json"
