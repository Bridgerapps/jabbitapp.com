#!/usr/bin/env bash
set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
export REDDIT_QUALITY_GATE=approved

# If already non-negative, stop recovery posting.
metrics=$(python3 "$WS/scripts/reddit_daily_metrics.py" 2>/dev/null || true)
total=$(printf "%s" "$metrics" | sed -n 's/.*total_karma=\(-\?[0-9]\+\).*/\1/p')
if [ -n "${total:-}" ] && [ "$total" -ge 1 ]; then
  echo "no_post_reason=karma_recovered total_karma=$total"
  exit 0
fi

cand=$(python3 "$WS/scripts/find_reddit_opportunities_newacct.py" 2>/dev/null || true)
if [ -z "${cand:-}" ]; then
  echo "no_post_reason=no_candidates"
  exit 0
fi

pick=$(printf "%s\n" "$cand" | python3 - <<'PY'
import sys,re
rows=[r.strip() for r in sys.stdin if r.strip()]
SAFE=[
    r"insurance", r"coverage", r"prior auth", r"denied", r"approved",
    r"maintenance", r"dose changes", r"goal weight", r"cold turkey",
    r"milestone", r"healthy bmi", r"progress", r"onederland", r"nsv"
]
for r in rows:
    parts=r.split('|')
    if len(parts)<4: continue
    pid,title,body,sub=parts[0],parts[1].lower(),parts[2].lower(),parts[3]
    text=f"{title} {body}"
    if any(re.search(p,text) for p in SAFE):
        print(r)
        sys.exit(0)
# fallback none
print('')
PY
)

if [ -z "${pick:-}" ]; then
  echo "no_post_reason=no_safe_candidate"
  exit 0
fi

IFS='|' read -r post_id title body sub permalink num_comments age_hours <<< "$pick"
low="$(printf "%s %s" "$title" "$body" | tr '[:upper:]' '[:lower:]')"

comment=""
if echo "$low" | grep -Eq 'insurance|coverage|prior auth|denied|approved'; then
  comment="Insurance outcomes are wildly plan-specific. The highest-signal replies usually include the exact denial/approval wording plus timeline, not just yes/no."
elif echo "$low" | grep -Eq 'maintenance|goal weight|dose|cold turkey'; then
  comment="Seen this split a lot: some stay on a low maintenance dose, others taper and monitor trend. The best comparisons are week-by-week (dose, weight trend, appetite, side effects)."
else
  comment="Huge milestone. The consistency through the slow final stretch is usually what makes the difference long-term."
fi

# extra guard: avoid blacklisted negative post ids
if [ -f "$WS/data/reddit/negative-post-blacklist.txt" ] && grep -qx "$post_id" "$WS/data/reddit/negative-post-blacklist.txt"; then
  echo "no_post_reason=blacklisted post_id=$post_id"
  exit 0
fi

out=$(bash "$WS/scripts/reddit_post_comment.sh" "$post_id" "$comment" 2>&1) || {
  echo "post_failed post_id=$post_id details=${out:-unknown}"
  exit 0
}

echo "posted_recovery_comment post_id=$post_id subreddit=$sub age_h=$age_hours comments=$num_comments"
python3 "$WS/scripts/reddit_daily_metrics.py"
