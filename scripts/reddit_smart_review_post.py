#!/usr/bin/env python3
"""Find Reddit opportunities, review with a quality rubric, and post at most one comment.

Goals:
- Improve karma with high-value comments.
- Keep risk low while account is recovering.
- Introduce subtle Jabbit mention only when signal is strong and thread intent fits.
"""

from __future__ import annotations

import argparse
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
LOW_VALUE_RE = re.compile(
    r"following this|thanks for sharing|good point\.?$|\breplies\b|\bthis thread\b|\bmost useful\b|\bhigh-signal\b|pattern that helps most",
    re.I,
)
APP_INTENT_RE = re.compile(r"what app|tracking app|tracker app|app recommendation|shotsy", re.I)
QUESTION_HEAVY_RE = re.compile(r"\?$")
GENERIC_META_RE = re.compile(r"\b(replies|thread|context|one-liners?)\b", re.I)


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


def direct_value_fallback(title: str, body: str) -> str:
    text = f"{title} {body}".lower()

    if re.search(r'meat aversion|food aversion|protein aversion', text):
        return "A lot of people do better with lighter protein during this phase (Greek yogurt, shakes, eggs, fish) and smaller portions spread through the day."
    if re.search(r'insurance|coverage|prior auth|denied|approved', text):
        return "If you post the exact denial/approval wording plus timeline, people can share much more specific playbooks that actually worked."
    if re.search(r'needle|pen needle|tips|purchase needles', text):
        return "Use only pen needles compatible with your device and confirm gauge/length from the manufacturer insert; pharmacies can usually match the exact spec same-day."
    if re.search(r'travel|flying|airport|tsa|trip', text):
        return "For travel, keep pens in your carry-on, use an insulated pouch, and bring a copy/photo of your prescription label in case security asks."
    if re.search(r'zero side effects|no side effects', text):
        return "No side effects can happen, especially early; the useful thing is tracking appetite, hydration, and bowel pattern week to week so changes are obvious if they show up later."
    if re.search(r'switching|restart|maintenance|goal weight|dose|mg|titrate', text):
        return "Best comparison data is week-by-week: dose, appetite/noise, weight trend, and side effects after each change."
    if re.search(r'side effect|symptom|nausea|fatigue|constipation|reflux|anxiety', text):
        return "Useful context to add: hours since last dose, current mg, hydration/food that day, and whether symptoms are improving or getting worse."

    return "Add your current dose, timing, and one concrete change this week; that usually gets much better practical replies."


def rewrite_comment(title: str, body: str, draft: str) -> str:
    """Force concrete, direct-value style. No meta commentary."""
    text = f"{title} {body}".lower()
    d = (draft or '').strip()

    # Replace meta/generic drafts outright.
    if (not d) or LOW_VALUE_RE.search(d) or GENERIC_META_RE.search(d):
        return direct_value_fallback(title, body)

    # If draft is only a question, upgrade with concrete value.
    if QUESTION_HEAVY_RE.search(d) and len(d.split()) < 20:
        return direct_value_fallback(title, body)

    # Topic-specific upgrades to avoid blandness.
    if re.search(r'meat aversion|food aversion|protein aversion', text):
        return "Meat aversion is common on GLP-1s; many people tolerate lighter protein better (Greek yogurt, shakes, eggs, fish) and smaller portions through the day."

    if re.search(r'needle|pen needle|tips|purchase needles', text):
        return "Use pen needles that match your device spec (gauge/length from the insert); most pharmacies can match the exact type if you show the pen model."

    if re.search(r'travel|flying|airport|tsa|trip', text):
        return "Travel tip: keep pens in carry-on (not checked bags), use a small insulated pouch, and keep your prescription label photo handy for security."

    if re.search(r'switching.*ozempic|switching|restart', text):
        return "When people share prior dose + gap length + first 2-week response after switching, it becomes much easier to compare what to expect."

    return d


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
    base = (p.stdout or '').strip()
    return rewrite_comment(title, body, base)


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
    anchors = ['insurance', 'coverage', 'dose', 'mg', 'maintenance', 'side effect', 'symptom', 'timeline', 'week-by-week', 'protein']
    blob = f"{comment} {txt}".lower()
    if any(a in blob for a in anchors):
        s += 2

    # Penalize generic wording that lacks direct practical value.
    if not re.search(r'\b(dose|mg|timeline|hydration|protein|side effects?|denial|approval|week)\b', comment.lower()):
        s -= 3

    return s


def main(auto_post: bool = False) -> int:
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
        if c.comments < 2 or c.comments > 80:
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

    # Strict quality threshold while recovering.
    threshold = 7 if total_karma < 1 else 6
    approved = [(sc, c, cm) for (sc, c, cm) in candidates if sc >= threshold]

    if not approved:
        top_sc, top_c, _ = candidates[0]
        print(f"no_post reason=low_quality best_score={top_sc} threshold={threshold} post_id={top_c.post_id} metrics={metrics_line}")
        return 0

    # Review-only mode by default: surface multiple high-quality opportunities.
    if not auto_post:
        top_n = approved[:3]
        print(f"approved_no_post count={len(top_n)} threshold={threshold}")
        for i, (sc, c, cm) in enumerate(top_n, start=1):
            print(f"candidate_{i} post_id={c.post_id} subreddit={c.subreddit} score={sc} url={c.permalink}")
            print(f"comment_{i}={cm}")
        print(metrics_line)
        return 0

    best_score, best, best_comment = approved[0]

    # Post exactly one (explicit mode only).
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
    parser = argparse.ArgumentParser()
    parser.add_argument('--post', action='store_true', help='Actually post approved comment (default: review only)')
    args = parser.parse_args()
    raise SystemExit(main(auto_post=args.post))
