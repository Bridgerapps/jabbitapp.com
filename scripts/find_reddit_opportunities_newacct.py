#!/usr/bin/env python3
"""
Reddit opportunity finder for NEW accounts.
Conservative filter to reduce moderation/reputation risk.

Output format (one line per opportunity):
post_id|title|selftext|subreddit|permalink|num_comments|age_hours
"""

import json
import os
import subprocess
import time
from datetime import datetime, UTC

TARGET_SUBS = [
    "Mounjaro", "Ozempic", "Zepbound", "Semaglutide", "Wegovy", "GLP1", "weightloss", "biohackers", "longevity"
]

MIN_COMMENTS = int(os.getenv("NEWACCT_MIN_COMMENTS", "3"))
MAX_COMMENTS = int(os.getenv("NEWACCT_MAX_COMMENTS", "40"))
MAX_AGE_HOURS = float(os.getenv("NEWACCT_MAX_AGE_HOURS", "18"))
MIN_AGE_MINUTES = float(os.getenv("NEWACCT_MIN_AGE_MINUTES", "20"))
MAX_PER_SUB = int(os.getenv("NEWACCT_MAX_PER_SUB", "3"))
MAX_TOTAL = int(os.getenv("NEWACCT_MAX_TOTAL", "20"))


def _load_env(path: str) -> dict:
    out = {}
    if not os.path.exists(path):
        return out
    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[len("export "):]
            if "=" not in line:
                continue
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def _curl_json(url: str, proxy: str, cookie: str) -> dict:
    ua = "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36"
    cmd = ["curl", "-sS", "--max-time", "30", "-A", ua, "-H", "Accept: application/json"]
    if proxy:
        cmd += ["-x", proxy]
    if cookie:
        cmd += ["-H", f"Cookie: reddit_session={cookie}"]
    cmd += [url]
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0 or not p.stdout.strip():
        return {}
    try:
        return json.loads(p.stdout)
    except Exception:
        return {}


def _score(d: dict) -> float:
    comments = d.get("num_comments", 0) or 0
    created = d.get("created_utc", 0) or 0
    age_h = (time.time() - created) / 3600.0 if created else 999.0

    score = 0.0
    # sweet spot: active but not saturated
    if 5 <= comments <= 25:
        score += 30
    elif MIN_COMMENTS <= comments <= MAX_COMMENTS:
        score += 20

    # recency sweet spot: not brand-new, not stale
    if 0.5 <= age_h <= 8:
        score += 25
    elif age_h <= MAX_AGE_HOURS:
        score += 10

    title = (d.get("title") or "").lower()
    text = f"{title} {(d.get('selftext') or '').lower()}"
    if "?" in title or "anyone" in text or "how" in title or "advice" in text:
        score += 10

    # avoid commercial-looking magnet threads for new acct
    risky = ["app", "tracker", "tracking app", "shotsy", "coupon", "affiliate", "promo", "discount"]
    if any(r in text for r in risky):
        score -= 25

    return score


def _safe(s: str) -> str:
    return (s or "").replace("|", "/").replace("\n", " ").replace("\r", " ").strip()


def main() -> int:
    ws = "/home/jabbit/.openclaw/workspace"
    proxy_env = _load_env(f"{ws}/scripts/proxy.env")
    reddit_env = _load_env(f"{ws}/scripts/reddit.env")

    proxy = proxy_env.get("REDDIT_PROXY_URL", "")
    username = reddit_env.get("REDDIT_USERNAME", "LifespanMaxer")
    cookie = ""
    try:
        with open(f"{ws}/.reddit-session", "r", encoding="utf-8") as f:
            cookie = f.read().strip()
    except Exception:
        pass

    if not cookie:
        print("ERROR: missing .reddit-session", flush=True)
        return 1

    now = datetime.now(UTC).timestamp()
    picks = []

    for sub in TARGET_SUBS:
        url = f"https://www.reddit.com/r/{sub}/new.json?limit=40"
        data = _curl_json(url, proxy, cookie)
        children = ((data.get("data") or {}).get("children") or [])[:40]

        sub_candidates = []
        for p in children:
            d = p.get("data") or {}
            if not d:
                continue
            if (d.get("author") or "") == username:
                continue
            if d.get("locked") or d.get("over_18"):
                continue
            if d.get("stickied"):
                continue

            created = d.get("created_utc", now) or now
            age_h = (now - created) / 3600.0
            age_m = (now - created) / 60.0
            comments = d.get("num_comments", 0) or 0

            if age_h > MAX_AGE_HOURS or age_m < MIN_AGE_MINUTES:
                continue
            if comments < MIN_COMMENTS or comments > MAX_COMMENTS:
                continue

            score = _score(d)
            if score <= 0:
                continue

            sub_candidates.append((score, d, age_h))

        sub_candidates.sort(key=lambda x: x[0], reverse=True)
        picks.extend(sub_candidates[:MAX_PER_SUB])

    picks.sort(key=lambda x: x[0], reverse=True)
    picks = picks[:MAX_TOTAL]

    for score, d, age_h in picks:
        print(
            "|".join([
                _safe(d.get("id", "")),
                _safe(d.get("title", "")),
                _safe(d.get("selftext", ""))[:400],
                _safe(d.get("subreddit", "")),
                _safe(d.get("permalink", "")),
                str(d.get("num_comments", 0) or 0),
                f"{age_h:.1f}",
            ])
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
