#!/bin/bash
# content-inventory.sh - Auto-generate content inventory from deployed files
# Usage: bash scripts/content-inventory.sh

JABBIT_DIR="/home/jabbit/.openclaw/workspace/jabbitapp.com"
OUTPUT_FILE="/home/jabbit/.openclaw/workspace/docs/content-inventory.md"

echo "=== Content Inventory Auto-Generator ==="
echo "Scanning: $JABBIT_DIR"

# Count GLP-1 pages
GLP1_COUNT=$(ls -1 "$JABBIT_DIR"/glp1*.html 2>/dev/null | wc -l)
echo "Found: $GLP1_COUNT GLP-1 pages"

# Get sitemap URL count
SITEMAP="$JABBIT_DIR/sitemap.xml"
if [ -f "$SITEMAP" ]; then
    SITEMAP_URLS=$(grep -c "<loc>" "$SITEMAP")
else
    SITEMAP_URLS="N/A"
fi
echo "Sitemap URLs: $SITEMAP_URLS"

# List all GLP-1 pages
echo ""
echo "=== GLP-1 Pages ==="
ls -1 "$JABBIT_DIR"/glp1*.html 2>/dev/null | xargs -n1 basename | sort

echo ""
echo "Inventory generated $(date -u +%Y-%m-%dT%H:%M UTC)"
echo "Total GLP-1 pages: $GLP1_COUNT"
echo "Total sitemap URLs: $SITEMAP_URLS"
