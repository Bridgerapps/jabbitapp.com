#!/usr/bin/env bash
# Notify IndexNow (Bing, Yandex, Seznam, Naver; Bing feeds DuckDuckGo + ChatGPT/Copilot search)
# about new/changed URLs. Usage: indexnow-ping.sh <url> [<url>...]   or   indexnow-ping.sh --sitemap
set -euo pipefail
HOST="www.jabbitapp.com"; KEY="73522986c019cecdab48e62c1709a683"; KEYLOC="https://$HOST/$KEY.txt"
if [ "${1:-}" = "--sitemap" ]; then
  mapfile -t URLS < <(curl -sL https://$HOST/sitemap.xml | grep -oE '<loc>[^<]+' | sed 's/<loc>//')
else URLS=("$@"); fi
[ ${#URLS[@]} -gt 0 ] || { echo "no URLs given"; exit 1; }
LIST=$(printf '%s\n' "${URLS[@]}" | python3 -c 'import sys,json;print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')
CODE=$(curl -s -o /tmp/indexnow.out -w '%{http_code}' -X POST https://api.indexnow.org/indexnow \
  -H 'Content-Type: application/json; charset=utf-8' \
  -d "{\"host\":\"$HOST\",\"key\":\"$KEY\",\"keyLocation\":\"$KEYLOC\",\"urlList\":$LIST}")
echo "IndexNow: HTTP $CODE for ${#URLS[@]} URL(s) (200/202 = accepted)"
[ "$CODE" = 200 ] || [ "$CODE" = 202 ]
