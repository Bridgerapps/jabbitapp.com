#!/usr/bin/env bash
# DEPRECATED: this script auto-posted comments via cookie auth.
# Policy: authenticated Reddit actions must be MANUAL-ONLY.
#
# Use the new operator flow:
#   bash scripts/reddit.sh manual discover
#   bash scripts/reddit.sh manual prepare --run <run.json> --post-id <id>
#   # post manually
#   bash scripts/reddit.sh manual log --status posted --comment-url '<comment-url>'

set -euo pipefail

echo "error: reddit_direct_comment_once.sh is disabled (manual-only policy)" >&2
exit 2
