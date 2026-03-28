#!/usr/bin/env bash
set -euo pipefail

# generate-awaiting-owner-top3.sh
# Purpose: create a small, curated shortlist of awaiting_owner items so owner pings
# can surface the *right* next approvals instead of dumping an unsorted backlog.
# Safe: local-only writes (data/status). No external sends.

ROOT="/home/jabbit/.openclaw/workspace"
LEDGER="${LEDGER:-$ROOT/data/status/manual-growth-loop-ledger.json}"
OUT_DIR="${OUT_DIR:-$ROOT/data/status}"
LIMIT="${LIMIT:-3}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

if [ ! -f "$LEDGER" ]; then
  echo "Ledger not found: $LEDGER" >&2
  exit 3
fi

mkdir -p "$OUT_DIR"

ts_utc=$(date -u +%FT%TZ)
ts_file=$(date -u +%Y-%m-%dT%H%M%SZ)

out_file="$OUT_DIR/manual-growth-loop-awaiting-owner-top3-${ts_file}.json"
latest_link="$OUT_DIR/manual-growth-loop-awaiting-owner-top3-latest.json"

# Priority:
#  0) awaitingOwnerReason==needs-approval (explicit approvals)
#  1) everything else
# Within priority: oldest awaitingOwnerUtc first (then updatedUtc)
# Keep the shape stable for downstream scripts.

jq -n \
  --arg ts_utc "$ts_utc" \
  --argjson limit "$LIMIT" \
  --slurpfile ledger "$LEDGER" \
  'def normUtc: (. // "9999-12-31T00:00:00Z");
   def prio:
     (if (.awaitingOwnerReason=="needs-approval") then 0 else 1 end);
   {
     schema: 1,
     updatedUtc: $ts_utc,
     top3: (
       ($ledger[0].sendQueues // [])
       | map(select(.status=="awaiting_owner"))
       | map({
           sendQueueId: .id,
           status: .status,
           awaitingOwnerReason: (.awaitingOwnerReason // null),
           awaitingOwnerUtc: (.awaitingOwnerUtc // null),
           updatedUtc: (.updatedUtc // null),
           channel: .channel,
           to: .to,
           subject: (.subject // null),
           brief: (.brief // null)
         })
       | sort_by([
           ((.awaitingOwnerReason=="needs-approval") | not),
           (.awaitingOwnerUtc | normUtc),
           (.updatedUtc | normUtc)
         ])
       | .[0:$limit]
     )
   }' \
  >"$out_file"

ln -sfn "$(basename "$out_file")" "$latest_link"

echo "WROTE: $out_file"
echo "UPDATED: $latest_link -> $(basename "$out_file")"
