#!/usr/bin/env python3
"""Find Reddit opportunities, review with a quality rubric, and post at most one comment.

Goals:
- Improve karma with high-value comments.
- Keep risk low while account is recovering.
- Introduce subtle Jabbit mention only when signal is strong and thread intent fits.
"""

from __future__ import annotations

import os
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path

WS = Path('/home/jabbit/.openclaw/workspace')
FINDER = WS / 'scripts' / 'find_reddit_opportunities_newacct.py'
METRICS = WS / 'scripts' / 'reddit_daily_metrics.py'
BLACKLIST_REFRESH = WS / 'scripts' / 'reddit_negative_feedback_blacklist.sh'
POST_SCRIPT = WS / 'scripts' / 'reddit_post_comment.sh'
POSTED_LOG = WS / 'data' / 'reddit' / 'posted-ids.txt'

ALLOWED_SUBS = {'mounjaro', 'ozempic', 'zepbound', 'wegovy', 'semaglutide', 'glp1', 'glp-1'}
RISK_RE = re.compile(r"shingles|emergency|chest pain|faint|suicid|pregnan|miscarriage|seizure|stroke|hospital|where can i buy|vendor|scam", re.I)
LOW_VALUE_RE = re.compile(r"following this|thanks for sharing|good point\.?$", re.I)
APP_INTENT_RE = re.compile(r"what app|tracking app|tracker app|app recommendation|shotsy", re.I)


@dataclass
class Cand:
    post_id: str
    subreddit: str
    title: str
    body: str
    permalink: str
    comments: int
    age_h: float


def run(cmd: list[str], timeout: int = 90) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def parse_metrics() -> tuple[int, int, str]:
    p = run(['python3', str(METRICS)], timeout=30)
    line = (p.stdout or '').strip()
    total = 0
    day = 0
    mt = re.search(r'total_karma=(-?\d+)', line)
    md = re.search(r'new_karma_today=(-?\d+)', line)
    if mt:
        total = int(mt.group(1))
    if md:
        day = int(md.group(1))
    return total, day, line


def load_posted_ids() -> set[str]:
    if not POSTED_LOG.exists():
        return set()
    return {x.strip() for x in POSTED_LOG.read_text(encoding='utf-8', errors='ignore').splitlines() if x.strip()}


def add_posted_id(pid: str):
    POSTED_LOG.parent.mkdir(parents=True, exist_ok=True)
    with POSTED_LOG.open('a', encoding='utf-8') as f:
        f.write(pid + '\n')


def load_candidates() -> list[Cand]:
    p = run(['python3', str(FINDER)], timeout=120)
    if p.returncode != 0:
        return []
    out = []
    for line in (p.stdout or '').splitlines():
        parts = line.split('|')
        if len(parts) < 7:
            continue
        pid, title, body, sub, permalink, ncom, ageh = parts[:7]
        try:
            comments = int(float(ncom or 0))
        except Exception:
            comments = 0
        try:
            age_h = float(ageh or 0)
        except Exception:
            age_h = 0.0
        out.append(Cand(
            post_id=pid.strip(),
            subreddit=sub.strip(),
            title=title.strip(),
            body=body.strip(),
            permalink=f"https://reddit.com{permalink.strip()}",
            comments=comments,
            age_h=age_h,
        ))
    return out


def gen_comment(title: str, body: str) -> str:
    code = (
        "import os,sys;"
        "sys.path.insert(0,'/home/jabbit/.openclaw/workspace/scripts');"
        "from reddit_comment_generator import build_value_comment;"
        "post={'title':os.environ.get('T',''),'selftext':os.environ.get('B','')};"
        "print(build_value_comment(post))"
    )
    p = subprocess.run(
        ['python3', '-c', code],
        capture_output=True,
        text=True,
        env={**os.environ, 'T': title, 'B': body},
        timeout=40,
    )
    return (p.stdout or '').strip()


def mention_jabbit_if_fit(comment: str, text: str, total_karma: int) -> str:
    # Only mention after account health improves.
    if total_karma < 3:
        return comment
    if not APP_INTENT_RE.search(text):
        return comment
    if re.search(r'\bjabbit\b', comment, re.I):
        return comment
    tail = " I use Jabbit for reminders + injection tracking because it keeps the workflow simple."
    return (comment + tail).strip()


def score_comment(c: Cand, comment: str) -> int:
    if not comment:
        return -999
    txt = f"{c.title} {c.body}"

    s = 0
    if len(comment.split()) >= 14:
        s += 2
    if len(comment.split()) <= 65:
        s += 1
    if c.comments >= 5 and c.comments <= 25:
        s += 2
    if c.age_h >= 0.5 and c.age_h <= 12:
        s += 2
    if LOW_VALUE_RE.search(comment):
        s -= 6
    if RISK_RE.search(txt):
        s -= 10

    # Context anchor bonus.
    anchors = ['insurance', 'coverage', 'dose', 'mg', 'maintenance', 'side effect', 'symptom', 'timeline']
    blob = f"{comment} {txt}".lower()
    if any(a in blob for a in anchors):
        s += 2

    return s


def main() -> int:
    # refresh blacklist best-effort
    subprocess.run(['bash', str(BLACKLIST_REFRESH)], capture_output=True, text=True, timeout=45)

    total_karma, day_gain, metrics_line = parse_metrics()
    posted = load_posted_ids()

    candidates = []
    for c in load_candidates():
        text = f"{c.title} {c.body}"
        sub = c.subreddit.lower()
        if sub not in ALLOWED_SUBS:
            continue
        if c.post_id in posted:
            continue
        if c.comments < 3 or c.comments > 35:
            continue
        if RISK_RE.search(text):
            continue

        comment = gen_comment(c.title, c.body)
        comment = mention_jabbit_if_fit(comment, text, total_karma)
        sc = score_comment(c, comment)
        candidates.append((sc, c, comment))

    if not candidates:
        print(f"no_post reason=no_candidates metrics={metrics_line}")
        return 0

    candidates.sort(key=lambda x: x[0], reverse=True)
    best_score, best, best_comment = candidates[0]

    # Strict quality threshold while recovering.
    threshold = 7 if total_karma < 1 else 6
    if best_score < threshold:
        print(f"no_post reason=low_quality best_score={best_score} threshold={threshold} post_id={best.post_id} metrics={metrics_line}")
        return 0

    # Post exactly one.
    p = subprocess.run(
        ['bash', str(POST_SCRIPT), best.post_id, best_comment],
        capture_output=True,
        text=True,
        env={**os.environ, 'REDDIT_QUALITY_GATE': 'approved'},
        timeout=60,
    )
    if p.returncode != 0:
        err = (p.stderr or p.stdout or '').strip().replace('\n', ' ')[:220]
        print(f"post_failed post_id={best.post_id} score={best_score} err={err}")
        return 0

    add_posted_id(best.post_id)
    print(f"posted post_id={best.post_id} subreddit={best.subreddit} score={best_score} url={best.permalink}")
    print(f"comment={best_comment}")
    print(run(['python3', str(METRICS)], timeout=30).stdout.strip())
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
