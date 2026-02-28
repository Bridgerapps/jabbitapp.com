#!/usr/bin/env bash
# Generate a batch of Reddit *draft* comments (NO POSTING).
#
# Why:
# - Turns "find opportunities" + "draft comments" into a 1-command workflow.
# - Produces a human-reviewable markdown queue you can paste from.
#
# Usage:
#   bash scripts/reddit-draft-batch.sh            # default limit
#   LIMIT=10 bash scripts/reddit-draft-batch.sh   # override
#
# Output:
#   output/reddit-drafts-YYYY-MM-DD.md

set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
DATE="$(date -u +%Y-%m-%d)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OUT_DIR="$WS/output"
OUT="$OUT_DIR/reddit-drafts-$DATE.md"
TMP_JSON="$OUT_DIR/.reddit-drafts-$DATE.json"

mkdir -p "$OUT_DIR"

LIMIT="${LIMIT:-8}"
export CAND_LIMIT="$LIMIT"

python3 "$WS/scripts/reddit_candidate_comments.py" > "$TMP_JSON"

# Format markdown (jq is already used across the workspace)
{
  echo "# Reddit Draft Queue — $DATE (UTC)"
  echo
  echo "Generated: $TS"
  echo "Source: scripts/reddit_candidate_comments.py (discovery only; no posting performed)"
  echo
  echo "Review before using:"
  echo "- Follow each subreddit’s rules (self-promo policies vary)."
  echo "- Avoid medical advice; keep to experience + questions + neutral framing."
  echo "- Do NOT post automatically from this script."
  echo
  echo "## Candidates"
  echo

  jq -r '
    if (type=="array" and length>0) then
      (to_entries[] | "### \((.key+1)) r/\(.value.subreddit)\n\n- Link: https://www.reddit.com\(.value.permalink)\n- Post id: \(.value.post_id)\n- Comments: \(.value.num_comments)\n- Age (hours): \(.value.age_hours)\n\n**Title:** \(.value.title)\n"
        + (if ((.value.body // "") | length) > 0 then "\n**Excerpt:**\n\n> " + ((.value.body | gsub("\r";" ") | gsub("\n";" "))[0:280]) + "\n" else "" end)
        + "\n**Draft:**\n\n> \(.value.proposed_comment)\n\n**Notes (fill in):**\n- ")
    else
      "(No candidates returned — either none matched filters, or discovery is blocked.)\n"
    end
  ' "$TMP_JSON"
} > "$OUT"

echo "reddit_draft_batch:ok:$OUT"
