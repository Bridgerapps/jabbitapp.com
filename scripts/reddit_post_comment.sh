#!/usr/bin/env bash
# DEPRECATED: authenticated Reddit actions must be MANUAL-ONLY.
#
# This script previously posted via session cookies + /api/comment.
# That is *not allowed* in this workspace because it is unattended authenticated automation.
#
# Use the manual operator flow instead:
#   bash scripts/reddit.sh manual discover
#   bash scripts/reddit.sh manual prepare --run <run.json> --post-id <id>
#   # post manually in browser/app
#   bash scripts/reddit.sh manual log --status posted --comment-url '<comment-url>'

set -euo pipefail

echo "error: reddit_post_comment.sh is disabled (manual-only policy)" >&2
exit 2
