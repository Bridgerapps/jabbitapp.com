#!/usr/bin/env python3
"""
Reddit opportunity finder for NEW accounts.
Conservative filter to reduce moderation/reputation risk.

Output format (one line per opportunity):
post_id|title|selftext|subreddit|permalink|num_comments|age_hours
"""

import json
import os
import re
import subprocess
import time
from datetime import datetime, UTC

TARGET_SUBS = [
    "Mounjaro", "Ozempic", "Zepbound", "Semaglutide", "Wegovy", "GLP1",
    "Peptides", "ResearchPeptides", "PeptidesForWeightLoss", "Retatrutide", "TirzepatideRX",
    "biohackers", "longevity", "Nootropics", "Supplements"
]
SHOTSY_FILE = "/home/jabbit/.openclaw/workspace/data/reddit/shotsy-opportunities.json"
SHOTSY_WATCHLIST = "/home/jabbit/.openclaw/workspace/data/reddit/shotsy-watch-subreddits.txt"

MIN_COMMENTS = int(os.getenv("NEWACCT_MIN_COMMENTS", "2"))
MAX_COMMENTS = int(os.getenv("NEWACCT_MAX_COMMENTS", "80"))
MAX_AGE_HOURS = float(os.getenv("NEWACCT_MAX_AGE_HOURS", "24"))
MIN_AGE_MINUTES = float(os.getenv("NEWACCT_MIN_AGE_MINUTES", "20"))
MAX_PER_SUB = int(os.getenv("NEWACCT_MAX_PER_SUB", "3"))
MAX_TOTAL = int(os.getenv("NEWACCT_MAX_TOTAL", "20"))
DISCOVERY_USE_COOKIE = os.getenv("REDDIT_DISCOVERY_USE_COOKIE", "false").lower() in ("1", "true", "yes")
DISCOVERY_COOKIE_FALLBACK = os.getenv("REDDIT_DISCOVERY_COOKIE_FALLBACK", "true").lower() in ("1", "true", "yes")
NEGATIVE_BLACKLIST_PATH = "/home/jabbit/.openclaw/workspace/data/reddit/negative-post-blacklist.txt"


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


def _curl_json(url: str, proxy: str, cookie: str = "") -> dict:
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


def _build_discovery_proxies(proxy_env: dict, fallback_proxy: str) -> list:
    """Build discovery proxy list; always prefer dedicated discovery subnet."""
    host = proxy_env.get("PROXY_HOST", "")
    port = proxy_env.get("PROXY_PORT", "80")
    user = proxy_env.get("PROXY_USER", "")
    pwd = proxy_env.get("PROXY_PASS", "")

    proxies = []
    if host and user and "US-" in user:
        m = re.search(r"US-(\d+)", user)
        current = int(m.group(1)) if m else 0
        prefix = re.sub(r"US-\d+", "US-", user)

        # Prefer all other subnets first, then current subnet last.
        for i in [1, 2, 3, 4, 5]:
            if i == current:
                continue
            proxies.append(f"http://{prefix}{i}:{pwd}@{host}:{port}")
        if current:
            proxies.append(f"http://{prefix}{current}:{pwd}@{host}:{port}")

    # Fallback to current action proxy if we couldn't build alternates.
    if not proxies and fallback_proxy:
        proxies = [fallback_proxy]

    # De-dup while preserving order.
    seen = set()
    out = []
    for p in proxies:
        if p and p not in seen:
            seen.add(p)
            out.append(p)
    return out


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


def _load_shotsy_subs(max_subs: int = 200):
    subs = []

    # Prefer explicit watchlist (all known subs where Shotsy was mentioned).
    try:
        with open(SHOTSY_WATCHLIST, "r", encoding="utf-8") as f:
            for raw in f:
                s = raw.strip()
                if s:
                    subs.append(s)
    except Exception:
        pass

    # Fallback/augment from latest opportunities file.
    try:
        with open(SHOTSY_FILE, "r", encoding="utf-8") as f:
            j = json.load(f)
        subs.extend([s for s in (j.get("tracked_subreddits") or []) if isinstance(s, str) and s.strip()])
    except Exception:
        pass

    # De-dup preserve order.
    out = []
    seen = set()
    for s in subs:
        if s not in seen:
            seen.add(s)
            out.append(s)

    return out[:max_subs]


def main() -> int:
    ws = "/home/jabbit/.openclaw/workspace"
    proxy_env = _load_env(f"{ws}/scripts/proxy.env")
    reddit_env = _load_env(f"{ws}/scripts/reddit.env")

    discovery_primary = proxy_env.get("DISCOVERY_REDDIT_PROXY_URL", "") or proxy_env.get("REDDIT_PROXY_URL", "")
    if (not discovery_primary) or ("${" in discovery_primary):
        host = proxy_env.get("PROXY_HOST", "")
        port = proxy_env.get("PROXY_PORT", "80")
        user = proxy_env.get("DISCOVERY_PROXY_USER", "") or proxy_env.get("PROXY_USER", "")
        pwd = proxy_env.get("PROXY_PASS", "")
        if host and user:
            discovery_primary = f"http://{user}:{pwd}@{host}:{port}"

    discovery_proxies = _build_discovery_proxies(proxy_env, discovery_primary)

    username = reddit_env.get("REDDIT_USERNAME", "LifespanMaxer")

    use_cookie_discovery = DISCOVERY_USE_COOKIE
    cookie_fallback = DISCOVERY_COOKIE_FALLBACK
    if "REDDIT_DISCOVERY_USE_COOKIE" in reddit_env:
        use_cookie_discovery = reddit_env.get("REDDIT_DISCOVERY_USE_COOKIE", "false").lower() in ("1", "true", "yes")
    if "REDDIT_DISCOVERY_COOKIE_FALLBACK" in reddit_env:
        cookie_fallback = reddit_env.get("REDDIT_DISCOVERY_COOKIE_FALLBACK", "true").lower() in ("1", "true", "yes")

    cookie = ""
    try:
        with open(f"{ws}/.reddit-session", "r", encoding="utf-8") as f:
            cookie = f.read().strip()
    except Exception:
        pass

    if not cookie and (use_cookie_discovery or cookie_fallback):
        print("ERROR: missing .reddit-session", flush=True)
        return 1

    now = datetime.now(UTC).timestamp()
    picks = []

    negative_blacklist = set()
    try:
        with open(NEGATIVE_BLACKLIST_PATH, "r", encoding="utf-8") as f:
            for line in f:
                x = line.strip()
                if x:
                    negative_blacklist.add(x)
    except FileNotFoundError:
        pass

    dynamic_shotsy_subs = _load_shotsy_subs(max_subs=200)
    scan_subs = list(dict.fromkeys(TARGET_SUBS + dynamic_shotsy_subs))

    for idx, sub in enumerate(scan_subs):
        url = f"https://www.reddit.com/r/{sub}/new.json?limit=40"
        discovery_proxy = discovery_proxies[idx % len(discovery_proxies)] if discovery_proxies else discovery_primary

        # Discovery defaults to no-cookie reads to reduce account linkage.
        data = _curl_json(url, discovery_proxy, cookie if use_cookie_discovery else "")
        children = ((data.get("data") or {}).get("children") or [])[:40]

        # Optional fallback to cookie-auth discovery when public reads are blocked/empty.
        if not children and cookie_fallback and cookie and not use_cookie_discovery:
            data = _curl_json(url, discovery_proxy, cookie)
            children = ((data.get("data") or {}).get("children") or [])[:40]

        sub_candidates = []
        for p in children:
            d = p.get("data") or {}
            if not d:
                continue
            if (d.get("author") or "") == username:
                continue
            post_id = (d.get("id") or "").strip()
            if post_id and post_id in negative_blacklist:
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
