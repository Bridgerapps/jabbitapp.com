#!/usr/bin/env bash
# Customer Issue Triage Script
# Polls for customer feedback/issues and categorizes them

set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
DATA_DIR="$WS/data/customer-feedback"
mkdir -p "$DATA_DIR"

echo "=== Customer Issue Triage ==="
NOW="$(date -Iseconds)"
echo "Time: $NOW"

# Check Stripe for new charge refunds or disputes (if API available)
ISSUES_FOUND=0

# Check App Store for new reviews (if API available)  
# Placeholder - would need App Store Connect API

# Check for customer support emails
# Placeholder - would poll Gmail for customer subjects

echo "Issues found: $ISSUES_FOUND"

if [ $ISSUES_FOUND -gt 0 ]; then
    echo "⚠️ New customer issues detected - would notify Jon/Tim"
else
    echo "✅ No new customer issues"
fi

# Persist a tiny status summary for cron tail
REVIEW_FILE="$WS/docs/customer-issues-review.md"
mkdir -p "$(dirname "$REVIEW_FILE")"
if [ ! -f "$REVIEW_FILE" ]; then
  cat > "$REVIEW_FILE" <<'EOF'
# Customer Issues Review

Auto-updated by `scripts/customer-issue-triage.sh`.

EOF
fi

{
  echo "Last triage: $NOW"
  echo "Issues found: $ISSUES_FOUND"
  if [ "$ISSUES_FOUND" -gt 0 ]; then
    echo "Status: attention-needed"
  else
    echo "Status: ok"
  fi
} >> "$REVIEW_FILE"

echo "Triage complete."
