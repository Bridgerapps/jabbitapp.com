#!/usr/bin/env python3
"""Build a human-review queue for Reddit comments (no auto-posting).

Outputs:
- data/reddit/review-queue-latest.json
- docs/reddit-comment-review-YYYY-MM-DD-HHMM.md
"""

from __future__ import annotations

import json
import os
import re
import subprocess
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path

WS = Path('/home/jabbit/.openclaw/workspace')
FINDER = WS / 'scripts' / 'find_reddit_opportunities_newacct.py'
BLACKLIST_REFRESH = WS / 'scripts' / 'reddit_negative_feedback_blacklist.sh'
METRICS = WS / 'scripts' / 'reddit_daily_metrics.py'

OUT_JSON = WS / 'data' / 'reddit' / 'review-queue-latest.json'
OUT_DOCS = WS / 'docs'

SAFE_INTENT_RE = re.compile(
    r"insurance|coverage|prior auth|denied|approved|maintenance|goal weight|dose|dosing|titrate|progress|milestone|nsv|onederland|side effect|symptom",
    re.I,
)
RISK_RE = re.compile(
    r"shingles|emergency|chest pain|faint|fainting|suicid|pregnan|miscarriage|seizure|stroke|hospital|source|vendor|where can i buy|scam",
    re.I,
)
PROMO_RE = re.compile(r"\bjabbit\b|\bshotsy\b", re.I)
LOW_VALUE_RE = re.compile(r"following this|thanks for sharing|good point\.?$", re.I)
TOPIC_RE = re.compile(r"mounjaro|ozempic|zepbound|wegovy|semaglutide|tirzepatide|glp-?1", re.I)
ALLOWED_SUBS = {"mounjaro", "ozempic", "zepbound", "wegovy", "semaglutide", "glp1", "glp-1"}


@dataclass
class Candidate:
    post_id: str
    subreddit: str
    permalink: str
    num_comments: int
    age_hours: float
    title: str
    proposed_comment: str
    rationale: str


def run(cmd: list[str], timeout: int = 60) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def load_candidates() -> list[dict]:
    p = run(['python3', str(FINDER)], timeout=90)
    if p.returncode != 0:
        return []
    out = []
    for line in (p.stdout or '').splitlines():
        parts = line.split('|')
        if len(parts) < 7:
            continue
        post_id, title, body, sub, permalink, num_comments, age_hours = parts[:7]
        try:
            nc = int(float(num_comments or 0))
        except Exception:
            nc = 0
        try:
            ah = float(age_hours or 0)
        except Exception:
            ah = 0.0
        out.append({
            'post_id': post_id.strip(),
            'title': title.strip(),
            'body': body.strip(),
            'subreddit': sub.strip(),
            'permalink': permalink.strip(),
            'num_comments': nc,
            'age_hours': ah,
        })
    return out


def build_comment(title: str, body: str) -> str:
    # Reuse existing generator for style consistency, but keep final human approval.
    code = (
        "import os,sys; sys.path.insert(0,'/home/jabbit/.openclaw/workspace/scripts');"
        "from reddit_comment_generator import build_value_comment;"
        "post={'title':os.environ.get('T',''),'selftext':os.environ.get('B','')};"
        "print(build_value_comment(post))"
    )
    p = subprocess.run(
        ['python3', '-c', code],
        capture_output=True,
        text=True,
        env={**os.environ, **{'T': title, 'B': body}},
        timeout=30,
    )
    return (p.stdout or '').strip()


def parse_metrics() -> str:
    p = run(['python3', str(METRICS)], timeout=30)
    if p.returncode == 0 and p.stdout.strip():
        return p.stdout.strip()
    return 'metrics_unavailable'


def main() -> int:
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_DOCS.mkdir(parents=True, exist_ok=True)

    # Keep blacklist fresh (best-effort).
    subprocess.run(['bash', str(BLACKLIST_REFRESH)], capture_output=True, text=True, timeout=45)

    metrics_line = parse_metrics()
    raw = load_candidates()

    picked: list[Candidate] = []
    for c in raw:
        text = f"{c['title']} {c['body']}"
        sub = (c['subreddit'] or '').strip().lower()
        if sub not in ALLOWED_SUBS:
            continue
        if not TOPIC_RE.search(text):
            continue
        if RISK_RE.search(text):
            continue
        if not SAFE_INTENT_RE.search(text):
            continue
        if c['num_comments'] < 3 or c['num_comments'] > 30:
            continue

        comment = build_comment(c['title'], c['body'])
        if not comment:
            continue
        if PROMO_RE.search(comment):
            continue
        if LOW_VALUE_RE.search(comment):
            continue

        rationale = 'safe-intent thread, non-promotional, context-specific'
        picked.append(Candidate(
            post_id=c['post_id'],
            subreddit=c['subreddit'],
            permalink=f"https://reddit.com{c['permalink']}",
            num_comments=c['num_comments'],
            age_hours=c['age_hours'],
            title=c['title'],
            proposed_comment=comment,
            rationale=rationale,
        ))
        if len(picked) >= 5:
            break

    now = datetime.now(timezone.utc)
    stamp = now.strftime('%Y-%m-%d-%H%M')
    md_path = OUT_DOCS / f'reddit-comment-review-{stamp}.md'

    payload = {
        'generated_at_utc': now.isoformat(),
        'metrics': metrics_line,
        'count': len(picked),
        'candidates': [asdict(x) for x in picked],
        'approval_rule': 'No auto-posting. Human must explicitly approve.',
    }
    OUT_JSON.write_text(json.dumps(payload, indent=2), encoding='utf-8')

    lines = []
    lines.append(f"# Reddit Comment Review Queue — {stamp} UTC\n")
    lines.append(f"Current metrics: `{metrics_line}`\n")
    lines.append("Policy: **No auto-posting. Human review required.**\n")

    if not picked:
        lines.append("No safe candidates found in this pass.")
    else:
        for i, c in enumerate(picked, start=1):
            lines.append(f"## {i}) {c.post_id} — r/{c.subreddit}")
            lines.append(f"- URL: {c.permalink}")
            lines.append(f"- Age/Comments: {c.age_hours:.1f}h / {c.num_comments}")
            lines.append(f"- Rationale: {c.rationale}")
            lines.append(f"- Title: {c.title}")
            lines.append(f"- Proposed comment: {c.proposed_comment}\n")

        lines.append("### Approval flow")
        lines.append("- Reply with: `approve <post_id>` to post one reviewed comment.")
        lines.append("- Reply with: `reject <post_id>` to skip.")
        lines.append("- Default if no instruction: do nothing.")

    md_path.write_text("\n".join(lines) + "\n", encoding='utf-8')

    if picked:
        ids = ', '.join(c.post_id for c in picked)
        print(f"review_queue_ready count={len(picked)} ids={ids} file={md_path}")
    else:
        print(f"review_queue_ready count=0 file={md_path}")

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
