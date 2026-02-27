#!/usr/bin/env bash
set -euo pipefail

# Canonical SEO/page count helper.
# Prefers counting URLs in the deployed site's sitemap.xml (single source of truth).
# Usage:
#   bash scripts/seo-count.sh            # prints integer count
#   bash scripts/seo-count.sh --json     # prints JSON details

WS="${WS:-/home/jabbit/.openclaw/workspace}"
SITE_DIR="${SITE_DIR:-$WS/jabbitapp.com}"
SITEMAP="${SITEMAP:-$SITE_DIR/sitemap.xml}"

count_from_sitemap() {
  local file="$1"
  grep -c '<loc>' "$file" 2>/dev/null || echo 0
}

count_from_files_fallback() {
  # Fallback if sitemap is missing: count HTML files that look like content.
  find "$SITE_DIR" -type f -name '*.html' \
    ! -name 'index.html' \
    ! -path '*/_includes/*' \
    | wc -l | tr -d ' '
}

SEO_PAGES=0
METHOD=""
if [ -f "$SITEMAP" ]; then
  SEO_PAGES="$(count_from_sitemap "$SITEMAP" | tr -d ' ')"
  METHOD="sitemap"
else
  SEO_PAGES="$(count_from_files_fallback)"
  METHOD="fallback-files"
fi

case "${1:-}" in
  --json)
    jq -n \
      --arg ws "$WS" \
      --arg site_dir "$SITE_DIR" \
      --arg sitemap "$SITEMAP" \
      --arg method "$METHOD" \
      --argjson seo_pages "$SEO_PAGES" \
      '{ws:$ws, site_dir:$site_dir, sitemap:$sitemap, method:$method, seo_pages:$seo_pages}'
    ;;
  *)
    echo "$SEO_PAGES"
    ;;
esac
