#!/usr/bin/env python3
"""Mine high-upvoted comment patterns from public Reddit threads (no auth cookie)."""

import json
import os
import re
import subprocess
import time
from collections import Counter

WS = "/home/jabbit/.openclaw/workspace"
OUT_JSON = f"{WS}/data/reddit/upvoted-comment-patterns.json"
OUT_MD = f"{WS}/docs/reddit-upvoted-patterns.md"
SUBS = os.getenv("PATTERN_SUBS", "Mounjaro,Ozempic,Zepbound").split(",")
TOP_POSTS_PER_SUB = int(os.getenv("PATTERN_TOP_POSTS_PER_SUB", "6"))
MIN_POST_COMMENTS = int(os.getenv("PATTERN_MIN_POST_COMMENTS", "20"))
MIN_COMMENT_SCORE = int(os.getenv("PATTERN_MIN_COMMENT_SCORE", "5"))
MAX_COMMENTS = int(os.getenv("PATTERN_MAX_COMMENTS", "120"))


def load_env(path: str) -> dict:
    out = {}
    if not os.path.exists(path):
        return out
    for raw in open(path, encoding="utf-8"):
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def load_proxy_info_from_shell() -> dict:
    cmd = (
        "source /home/jabbit/.openclaw/workspace/scripts/proxy.env >/dev/null 2>&1 || true; "
        "printf '{\"REDDIT_PROXY_URL\":\"%s\",\"PROXY_HOST\":\"%s\",\"PROXY_PORT\":\"%s\",\"PROXY_USER\":\"%s\",\"PROXY_PASS\":\"%s\"}' "
        "\"${REDDIT_PROXY_URL:-}\" \"${PROXY_HOST:-}\" \"${PROXY_PORT:-}\" \"${PROXY_USER:-}\" \"${PROXY_PASS:-}\""
    )
    p = subprocess.run(["bash", "-lc", cmd], capture_output=True, text=True)
    if p.returncode != 0 or not p.stdout.strip():
        return {}
    try:
        return json.loads(p.stdout)
    except Exception:
        return {}


def build_proxies(proxy_env: dict):
    host = proxy_env.get("PROXY_HOST", "")
    port = proxy_env.get("PROXY_PORT", "80")
    user = proxy_env.get("PROXY_USER", "")
    pwd = proxy_env.get("PROXY_PASS", "")
    proxies = []

    reddit_proxy = proxy_env.get("REDDIT_PROXY_URL", "")
    if reddit_proxy and "${" not in reddit_proxy:
        proxies.append(reddit_proxy)

    if host and user and "US-" in user:
        prefix = re.sub(r"US-\d+", "US-", user)
        for i in [1, 2, 3, 4, 5]:
            proxies.append(f"http://{prefix}{i}:{pwd}@{host}:{port}")
    elif host and user:
        proxies.append(f"http://{user}:{pwd}@{host}:{port}")

    # dedupe preserve order
    seen, out = set(), []
    for p in proxies:
        if p and p not in seen:
            seen.add(p)
            out.append(p)
    return out


def curl_json(url: str, proxy: str = ""):
    ua = "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36"
    cmd = ["curl", "-sS", "--max-time", "30", "-A", ua, "-H", "Accept: application/json"]
    if proxy:
        cmd += ["-x", proxy]
    cmd += [url]
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0 or not p.stdout.strip():
        return {}
    try:
        return json.loads(p.stdout)
    except Exception:
        return {}


def clean_text(s: str) -> str:
    s = re.sub(r"\s+", " ", (s or "").strip())
    return s


def first_clause(s: str) -> str:
    s = clean_text(s)
    m = re.split(r"[.!?]", s)
    return m[0][:120].lower() if m and m[0] else s[:120].lower()


def analyze(comments):
    if not comments:
        return {}
    word_counts = [len(re.findall(r"\w+", c["body"])) for c in comments]
    q_count = sum(1 for c in comments if c["body"].strip().endswith("?"))
    personal = sum(1 for c in comments if re.search(r"\b(i|my|me|i've|i’m|im)\b", c["body"].lower()))
    concrete = sum(1 for c in comments if re.search(r"\b(week|month|mg|dose|hours?|days?|lbs?|kg|sleep|hydration|protein)\b", c["body"].lower()))
    empathy = sum(1 for c in comments if re.search(r"\b(sorry|that sucks|rough|brutal|totally|get it)\b", c["body"].lower()))

    openers = Counter(first_clause(c["body"]) for c in comments)
    top_openers = [o for o, _ in openers.most_common(8)]

    return {
        "sample_size": len(comments),
        "avg_words": round(sum(word_counts) / len(word_counts), 1),
        "question_ending_pct": round(q_count * 100 / len(comments), 1),
        "personal_experience_pct": round(personal * 100 / len(comments), 1),
        "concrete_detail_pct": round(concrete * 100 / len(comments), 1),
        "empathy_pct": round(empathy * 100 / len(comments), 1),
        "top_openers": top_openers,
    }


def main():
    os.makedirs(f"{WS}/data/reddit", exist_ok=True)
    os.makedirs(f"{WS}/docs", exist_ok=True)

    proxy_env = load_env(f"{WS}/scripts/proxy.env")
    shell_proxy = load_proxy_info_from_shell()
    proxy_env.update({k: v for k, v in shell_proxy.items() if v})
    proxies = build_proxies(proxy_env)
    if not proxies:
        proxies = [""]

    collected = []
    proxy_idx = 0

    for sub in [s.strip() for s in SUBS if s.strip()]:
        proxy = proxies[proxy_idx % len(proxies)]
        proxy_idx += 1
        posts = curl_json(f"https://www.reddit.com/r/{sub}/top.json?t=day&limit=25", proxy)
        children = ((posts.get("data") or {}).get("children") or [])

        chosen = []
        for p in children:
            d = p.get("data") or {}
            if (d.get("num_comments") or 0) < MIN_POST_COMMENTS:
                continue
            if d.get("stickied"):
                continue
            chosen.append(d)
            if len(chosen) >= TOP_POSTS_PER_SUB:
                break

        for post in chosen:
            pid = post.get("id")
            if not pid:
                continue
            proxy = proxies[proxy_idx % len(proxies)]
            proxy_idx += 1
            cj = curl_json(f"https://www.reddit.com/comments/{pid}.json?sort=top&limit=200&raw_json=1", proxy)
            if not isinstance(cj, list) or len(cj) < 2:
                continue
            comments = (((cj[1] or {}).get("data") or {}).get("children") or [])
            for c in comments:
                d = c.get("data") or {}
                body = clean_text(d.get("body", ""))
                if not body or body in ("[deleted]", "[removed]"):
                    continue
                if d.get("score", 0) < MIN_COMMENT_SCORE:
                    continue
                if d.get("author") in ("AutoModerator",):
                    continue
                collected.append(
                    {
                        "subreddit": sub,
                        "post_id": pid,
                        "post_title": post.get("title", ""),
                        "comment_id": d.get("id", ""),
                        "score": d.get("score", 0),
                        "body": body,
                        "permalink": "https://reddit.com" + (d.get("permalink") or ""),
                    }
                )

    collected.sort(key=lambda x: x["score"], reverse=True)
    collected = collected[:MAX_COMMENTS]

    analysis = analyze(collected)

    style_hints = {
        "target_avg_words": max(14, min(38, int(round((analysis.get("avg_words") or 22))))),
        "prefer_question_endings": (analysis.get("question_ending_pct") or 0) > 25,
        "require_concrete_detail": True,
        "prefer_personal_or_direct": True,
        "avoid_meta_discussion": True,
    }

    payload = {
        "generated_at": int(time.time()),
        "subs": SUBS,
        "thresholds": {
            "min_post_comments": MIN_POST_COMMENTS,
            "min_comment_score": MIN_COMMENT_SCORE,
        },
        "analysis": analysis,
        "style_hints": style_hints,
        "top_examples": collected[:25],
    }

    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    lines = [
        "# Reddit Upvoted Comment Patterns",
        "",
        f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime(payload['generated_at']))}",
        f"Samples: {analysis.get('sample_size', 0)}",
        "",
        "## Style Metrics",
        f"- Avg words: {analysis.get('avg_words', 'n/a')}",
        f"- Personal experience %: {analysis.get('personal_experience_pct', 'n/a')}%",
        f"- Concrete detail %: {analysis.get('concrete_detail_pct', 'n/a')}%",
        f"- Question-ending %: {analysis.get('question_ending_pct', 'n/a')}%",
        "",
        "## Top Openers",
    ]
    for op in analysis.get("top_openers", [])[:8]:
        lines.append(f"- {op}")

    lines += ["", "## Best Examples"]
    for ex in collected[:12]:
        lines.append(f"- ({ex['score']} upvotes) r/{ex['subreddit']}: {ex['body'][:220]}")

    with open(OUT_MD, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    print(f"patterns_mined={analysis.get('sample_size', 0)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
