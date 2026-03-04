#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-discovery}"  # discovery only (auth rotation disabled)
WS="/home/jabbit/.openclaw/workspace"
ENV_FILE="$WS/scripts/proxy.env"
COOKIE_FILE="$WS/.reddit-session"

# HARD REQUIREMENT (Jon 2026-03-04): do NOT rotate IP for authenticated Reddit traffic.
# This script may only rotate discovery proxies. Auth proxy rotation is disabled.
if [ "$MODE" = "auth" ]; then
  echo "error: auth proxy rotation disabled (use stable auth IP/subnet)" >&2
  exit 2
fi

[ -f "$ENV_FILE" ] || { echo "error: missing $ENV_FILE"; exit 1; }
source "$ENV_FILE"

SUBNETS=(US-1 US-2 US-3 US-4 US-5)

pick_var="AUTH_PROXY_USER"
if [ "$MODE" = "discovery" ]; then
  pick_var="DISCOVERY_PROXY_USER"
fi

current="${!pick_var:-}"
current_subnet=$(echo "$current" | grep -oE 'US-[0-9]+' || true)
[ -n "$current_subnet" ] || current_subnet="US-1"

build_url() {
  local user="$1"
  echo "http://${user}:${PROXY_PASS}@${PROXY_HOST}:${PROXY_PORT}"
}

test_discovery() {
  local url="$1"
  local out
  out=$(curl -sS --max-time 18 -x "$url" -A 'Mozilla/5.0' -H 'Accept: application/json' "https://www.reddit.com/search.json?q=shotsy&sort=new&t=day&type=link&limit=5&raw_json=1" || true)
  echo "$out" | jq -e '.data.children' >/dev/null 2>&1
}

# Try all other subnets first, then current as last resort.
order=()
for s in "${SUBNETS[@]}"; do
  [ "$s" = "$current_subnet" ] && continue
  order+=("$s")
done
order+=("$current_subnet")

for s in "${order[@]}"; do
  user="jxrtqjko-${s}"
  url=$(build_url "$user")
  ok=1
  test_discovery "$url" && ok=0 || ok=1

  if [ "$ok" -eq 0 ]; then
    # Update selected proxy user in env file
    sed -i "s|^export ${pick_var}=\"jxrtqjko-US-[0-9]\+\"|export ${pick_var}=\"${user}\"|" "$ENV_FILE"
    echo "rotated mode=${MODE} subnet=${s} user=${user}"
    exit 0
  fi
done

echo "rotate_failed mode=${MODE}"
exit 1
