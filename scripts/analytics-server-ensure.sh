#!/usr/bin/env bash
set -euo pipefail

# Ensures the local analytics service is running.
# Safe to call repeatedly.
#
# Behavior:
# - If /health responds: do nothing.
# - If port 9000 is bound but /health fails: exit non-zero (someone else is on the port).
# - If port is free: start /home/jabbit/analytics (nohup) and re-check.

ANALYTICS_DIR="/home/jabbit/analytics"
BASE_URL="http://127.0.0.1:9000"

health_ok() {
  curl -sS --max-time 1 "$BASE_URL/health" | jq -e '.ok==true' >/dev/null 2>&1
}

port_bound() {
  ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE '(:|\])9000$'
}

if health_ok; then
  exit 0
fi

if port_bound; then
  echo "analytics-server-ensure: port 9000 is bound but $BASE_URL/health is not responding" >&2
  exit 2
fi

if [ ! -d "$ANALYTICS_DIR" ]; then
  echo "analytics-server-ensure: missing $ANALYTICS_DIR" >&2
  exit 3
fi

# Start service (best-effort). Use .env if present.
(
  cd "$ANALYTICS_DIR"
  if [ -f ".env" ]; then
    set -a
    # shellcheck disable=SC1091
    source ./.env
    set +a
  fi

  # If npm is missing, fall back to node.
  if command -v npm >/dev/null 2>&1; then
    nohup npm start >>"$ANALYTICS_DIR/analytics.log" 2>&1 &
  else
    nohup node index.js >>"$ANALYTICS_DIR/analytics.log" 2>&1 &
  fi
)

# Give it a moment to bind.
sleep 0.5

if health_ok; then
  exit 0
fi

echo "analytics-server-ensure: failed to start (no health response)" >&2
exit 4
