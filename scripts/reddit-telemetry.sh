#!/usr/bin/env bash
set -euo pipefail

# Reddit telemetry normalizer.
# - Reads data/reddit/reddit-health.json (if present)
# - Maintains data/karma-tracker.json with last-known + stale marker
# - Emits canonical status JSON for dashboards: data/status/reddit.json

WS="${WS:-/home/jabbit/.openclaw/workspace}"
REDDIT_HEALTH_FILE="$WS/data/reddit/reddit-health.json"
KARMA_FILE="$WS/data/karma-tracker.json"
OUT_FILE="$WS/data/status/reddit.json"

mkdir -p "$WS/data/status" "$WS/data"

now_iso="$(date -u -Iseconds)"
now_epoch="$(date -u +%s)"

# --- Reddit API health ---
reddit_status="UNKNOWN"
reddit_timestamp=""
reddit_age_s="null"
reddit_fresh=false
reddit_checks='[]'

if [ -f "$REDDIT_HEALTH_FILE" ]; then
  reddit_status="$(jq -r '.status // "UNKNOWN"' "$REDDIT_HEALTH_FILE" 2>/dev/null || echo "UNKNOWN")"
  reddit_timestamp="$(jq -r '.timestamp // ""' "$REDDIT_HEALTH_FILE" 2>/dev/null || echo "")"
  reddit_checks="$(jq -c '.checks // []' "$REDDIT_HEALTH_FILE" 2>/dev/null || echo '[]')"

  if [ -n "$reddit_timestamp" ]; then
    ts_epoch="$(date -u -d "$reddit_timestamp" +%s 2>/dev/null || echo 0)"
    if [ "$ts_epoch" -gt 0 ]; then
      age=$(( now_epoch - ts_epoch ))
      reddit_age_s="$age"
      # fresh if updated in last 6 hours
      if [ "$age" -le $((6*3600)) ]; then
        reddit_fresh=true
      fi
    fi
  fi
fi

# Normalize status label for dashboards
case "$reddit_status" in
  OK|ok|WORKING|working)
    reddit_status="WORKING";;
  DEGRADED|degraded)
    reddit_status="DEGRADED";;
  DOWN|down|FAIL|fail)
    reddit_status="DOWN";;
  *)
    reddit_status="${reddit_status:-UNKNOWN}";;
esac

# --- Karma tracker ---
# If REDDIT_USERNAME is set, attempt an unauthenticated fetch from /about.json.
# If it fails, preserve last-known and mark stale.
karma_total="null"
karma_updated_at=""
karma_stale=true
karma_source="last-known"

if [ -f "$KARMA_FILE" ]; then
  karma_total="$(jq -r '.total_karma // null' "$KARMA_FILE" 2>/dev/null || echo null)"
  karma_updated_at="$(jq -r '.updated_at // ""' "$KARMA_FILE" 2>/dev/null || echo "")"
  karma_stale="$(jq -r '.stale // true' "$KARMA_FILE" 2>/dev/null || echo true)"
fi

# Load local reddit identity defaults if present
if [ -f "$WS/scripts/reddit.env" ]; then
  # shellcheck disable=SC1090
  source "$WS/scripts/reddit.env"
fi

REDDIT_USERNAME="${REDDIT_USERNAME:-LifespanMaxer}"

if [ -n "${REDDIT_USERNAME:-}" ]; then
  set +e
  curl_args=( -sS -A 'Mozilla/5.0 (compatible; OpenClaw/1.0)' "https://www.reddit.com/user/${REDDIT_USERNAME}/about.json?raw_json=1" )
  if [ -f "$WS/scripts/proxy.env" ]; then
    # shellcheck disable=SC1090
    source "$WS/scripts/proxy.env"
    if [ -n "${REDDIT_PROXY_URL:-}" ]; then
      curl_args=( -x "$REDDIT_PROXY_URL" "${curl_args[@]}" )
    fi
  fi
  if [ -f "$WS/.reddit-session" ]; then
    cookie="$(tr -d '[:space:]' < "$WS/.reddit-session")"
    if [ -n "$cookie" ]; then
      curl_args=( -H "Cookie: reddit_session=${cookie}" "${curl_args[@]}" )
    fi
  fi
  about_json="$(curl "${curl_args[@]}")"
  rc=$?
  set -e

  if [ $rc -eq 0 ] && [ -n "$about_json" ]; then
    fetched="$(printf '%s' "$about_json" | jq -r '.data.total_karma // "null"' 2>/dev/null || echo "null")"

    if [ "$fetched" != "null" ]; then
      karma_total="$fetched"
      karma_updated_at="$now_iso"
      karma_stale=false
      karma_source="reddit-about"
    fi
  fi
fi

# Persist karma file (always), so dashboards have a stable path.
cat > "$KARMA_FILE" <<EOF
{
  "updated_at": "${karma_updated_at:-$now_iso}",
  "total_karma": ${karma_total:-null},
  "stale": ${karma_stale:-true},
  "source": "${karma_source}",
  "username": "${REDDIT_USERNAME:-}"
}
EOF

# Emit canonical reddit status JSON
jq -n \
  --arg last_check "$now_iso" \
  --arg status "$reddit_status" \
  --arg source_file "data/reddit/reddit-health.json" \
  --arg reddit_timestamp "$reddit_timestamp" \
  --argjson age_seconds "$reddit_age_s" \
  --argjson fresh "$( [ "$reddit_fresh" = true ] && echo true || echo false )" \
  --argjson checks "$reddit_checks" \
  --argjson karma_total "$karma_total" \
  --arg karma_updated_at "${karma_updated_at:-$now_iso}" \
  --argjson karma_stale "$( [ "${karma_stale:-true}" = true ] && echo true || echo false )" \
  '{last_check:$last_check, status:$status, source_file:$source_file, reddit_timestamp:$reddit_timestamp, age_seconds:$age_seconds, fresh:$fresh, checks:$checks, karma:{total:$karma_total, updated_at:$karma_updated_at, stale:$karma_stale}}' \
  > "$OUT_FILE"

echo "$OUT_FILE"
