#!/usr/bin/env bash
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
source "$WS/scripts/proxy.env" 2>/dev/null || true
source "$WS/scripts/reddit.env" 2>/dev/null || true

UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
username="${REDDIT_USERNAME:-LifespanMaxer}"

# --- IMPORTANT POLICY ---
# This script must be safe under cron.
# Default behavior: PUBLIC-ONLY visibility check (no cookie reads, no auth calls).
# Authenticated checks are MANUAL-ONLY and require explicit flags + interactive run.

manual_auth=false
if [ "${REDDIT_MANUAL_AUTH:-}" = "true" ] && [ "${REDDIT_MANUAL_HEALTHCHECK_AUTH:-}" = "true" ]; then
  manual_auth=true
fi

if [ "$manual_auth" = true ] && ! [ -t 0 ]; then
  echo "error: refusing non-interactive auth healthcheck" >&2
  exit 2
fi

# Conservative guard to avoid repetitive checks in tight loops.
STATE_FILE="$WS/data/reddit/.account-health-check.state"
MIN_INTERVAL_SEC="${REDDIT_ACCOUNT_HEALTH_MIN_INTERVAL_SEC:-1800}" # 30 min default
mkdir -p "$WS/data/reddit"
now=$(date +%s)
last=0
if [ -f "$STATE_FILE" ]; then
  last=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
fi
if [ $((now - last)) -lt "$MIN_INTERVAL_SEC" ]; then
  echo NO_REPLY
  exit 0
fi
printf "%s" "$now" > "$STATE_FILE"

# Proxies: public via discovery; auth via auth proxy (stable IP).
PUB_PROXY="${DISCOVERY_REDDIT_PROXY_URL:-${REDDIT_PROXY_URL:-}}"
AUTH_PROXY="${AUTH_REDDIT_PROXY_URL:-${REDDIT_PROXY_URL:-}}"

base_args=(-sS --max-time 15 -A "$UA")
pub_args=("${base_args[@]}")
[ -n "${PUB_PROXY:-}" ] && pub_args=(-x "$PUB_PROXY" "${pub_args[@]}")

# --- Public visibility check (unauthenticated) ---
pub=$(curl "${pub_args[@]}" "https://www.reddit.com/user/${username}/about.json?raw_json=1" || true)

# Reddit sometimes returns a blocked HTML page for public profile endpoints from some networks.
# Do not misclassify that as account trouble.
if printf "%s" "$pub" | grep -qiE 'whoa there, pardner|request has been blocked due to a network policy|<html'; then
  echo "Reddit public-profile check blocked by network policy; account status unknown from unauthenticated profile probe."
  exit 0
fi

pub_err=$(printf "%s" "$pub" | jq -r '.error // 0' 2>/dev/null || echo 0)

if [ "$pub_err" = "404" ]; then
  echo "Reddit visibility alert: public profile returns 404 (possible profile restriction or username mismatch)."
  exit 0
fi

# --- Optional manual auth check (single endpoint) ---
if [ "$manual_auth" = true ]; then
  if [ -z "${AUTH_PROXY:-}" ]; then
    echo "Reddit auth check blocked: missing AUTH_REDDIT_PROXY_URL (stable auth IP required)."
    exit 0
  fi

  COOKIE=$(tr -d '[:space:]' < "$WS/.reddit-session" 2>/dev/null || true)
  if [ -z "$COOKIE" ]; then
    echo "Reddit session may be expired/invalid. Send a fresh reddit_session cookie."
    exit 0
  fi

  auth_args=("${base_args[@]}")
  auth_args=(-x "$AUTH_PROXY" "${auth_args[@]}")

  me=$(curl "${auth_args[@]}" -H "Cookie: reddit_session=${COOKIE}" "https://www.reddit.com/api/me.json?raw_json=1" || true)
  me_name=$(printf "%s" "$me" | jq -r '.data.name // empty' 2>/dev/null || true)
  me_suspended=$(printf "%s" "$me" | jq -r '.data.is_suspended // false' 2>/dev/null || echo false)

  if [ -z "$me_name" ]; then
    echo "Reddit session may be expired/invalid. Send a fresh reddit_session cookie."
  elif [ "$me_name" != "$username" ]; then
    echo "Reddit auth mismatch: expected=$username got=$me_name. Rotate cookie now."
  elif [ "$me_suspended" = "true" ]; then
    echo "Reddit account alert: account appears suspended. Pause actions and appeal."
  else
    echo NO_REPLY
  fi
  exit 0
fi

# If public check looks OK and we're not doing manual auth checks, stay quiet.
echo NO_REPLY
