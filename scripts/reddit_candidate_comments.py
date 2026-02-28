#!/usr/bin/env python3
"""Generate candidate Reddit comments for LLM review before posting."""
import json
import os
import subprocess
import sys

sys.path.insert(0, "/home/jabbit/.openclaw/workspace/scripts")
from reddit_comment_generator import build_value_comment

WS = "/home/jabbit/.openclaw/workspace"
LIMIT = int(os.getenv("CAND_LIMIT", "6"))


def main() -> int:
    p = subprocess.run(
        ["python3", f"{WS}/scripts/find_reddit_opportunities_newacct.py"],
        capture_output=True,
        text=True,
    )
    if p.returncode != 0:
        print("[]")
        return 0

    out = []
    for raw in p.stdout.splitlines():
        if len(out) >= LIMIT:
            break
        parts = raw.split("|", 6)
        if len(parts) != 7:
            continue
        post_id, title, body, sub, permalink, num_comments, age_hours = parts
        post = {"title": title, "selftext": body}
        comment = (build_value_comment(post) or "").strip()
        if not comment:
            continue
        out.append(
            {
                "post_id": post_id,
                "title": title,
                "body": body,
                "subreddit": sub,
                "permalink": permalink,
                "num_comments": int(float(num_comments or 0)),
                "age_hours": float(age_hours or 0),
                "proposed_comment": comment,
            }
        )

    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
