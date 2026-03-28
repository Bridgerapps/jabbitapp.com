#!/usr/bin/env python3
"""Generate a human-reviewable distribution pack for a static HTML page.

Why:
- We keep shipping new SEO pages, then repeatedly ask: “what should we post where?”
- This script turns an on-disk HTML page into ready-to-copy snippets.

Safety:
- NO posting. Output is just a markdown file under /output for human review.
- Pulls only verifiable strings from the page (title, meta description, H1) to avoid
  inventing claims.

Usage:
  python3 scripts/distribution-pack.py --file wegovy-injection-tracker.html
  python3 scripts/distribution-pack.py --path /home/jabbit/.openclaw/workspace/jabbitapp.com/wegovy-injection-tracker.html

Output:
  output/distribution-pack-YYYY-MM-DD-<slug>.md (UTC)
"""

from __future__ import annotations

import argparse
import pathlib
import re
from datetime import datetime, timezone

WS = pathlib.Path("/home/jabbit/.openclaw/workspace")
SITE_DIR = WS / "jabbitapp.com"
OUT_DIR = WS / "output"
BASE = "https://jabbitapp.com/"

TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.IGNORECASE | re.DOTALL)
DESC_RE = re.compile(
    r"<meta[^>]+name=(?:\"|')description(?:\"|')[^>]+content=(?:\"|')(.*?)(?:\"|')[^>]*>",
    re.IGNORECASE | re.DOTALL,
)
H1_RE = re.compile(r"<h1[^>]*>(.*?)</h1>", re.IGNORECASE | re.DOTALL)
TAG_RE = re.compile(r"<[^>]+>")
WS_RE = re.compile(r"\s+")


def iso_utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _strip_tags(s: str) -> str:
    s = TAG_RE.sub(" ", s or "")
    s = s.replace("&amp;", "&").replace("&nbsp;", " ")
    s = WS_RE.sub(" ", s).strip()
    return s


def _extract_first(rx: re.Pattern[str], html: str) -> str:
    m = rx.search(html or "")
    return _strip_tags(m.group(1)) if m else ""


def _tweet_variants(title: str, desc: str, h1: str, url: str) -> list[str]:
    # Keep tweets low-claim: reuse title/desc verbatim; no invented numbers/benefits.
    t = title or h1 or "New page"
    d = desc

    v1 = f"{t} — {url}"

    if d:
        v2 = f"{t}. {d} {url}"
    else:
        v2 = v1

    # Question-style variant for engagement; still facts-only.
    h = h1 or ""
    if h:
        v3 = f"{h} — what do you track each week (date/time, site rotation, notes)? {url}"
    else:
        v3 = f"What do you track each week (date/time, site rotation, notes)? {url}"

    # Trim to Twitter length budget-ish without being fancy.
    def trim(s: str, n: int = 275) -> str:
        s = WS_RE.sub(" ", s).strip()
        return s if len(s) <= n else (s[: n - 1].rstrip() + "…")

    return [trim(v1), trim(v2), trim(v3)]


def _reddit_comment_variants(desc: str, url: str) -> list[str]:
    # Value-first, not medical advice, no dosing directives.
    c1 = (
        "If you’re trying to make side effects / routines easier to reason about, what helped me was a simple timeline: "
        "date/time, injection site (for rotation), and 1–2 notes about meals/sleep/stress. "
        "Not medical advice — just making the log useful. "
        f"I put a plain tracker page here: {url}"
    )

    c2 = (
        "Question for folks who’ve dialed this in: what’s the *minimum viable* injection log you actually keep up with? "
        "(I’ve found consistency beats detail.) "
        f"Related page: {url}"
    )

    return [c1, c2]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", default=None, help="Filename under jabbitapp.com/ (e.g., wegovy-injection-tracker.html)")
    ap.add_argument("--path", default=None, help="Full path to an HTML file")
    args = ap.parse_args()

    if bool(args.file) == bool(args.path):
        raise SystemExit("Provide exactly one of --file or --path")

    if args.file:
        page = SITE_DIR / args.file
    else:
        page = pathlib.Path(args.path)

    if not page.exists():
        raise SystemExit(f"Missing file: {page}")

    html = page.read_text(encoding="utf-8", errors="replace")

    title = _extract_first(TITLE_RE, html)
    desc = _extract_first(DESC_RE, html)
    h1 = _extract_first(H1_RE, html)

    url = BASE + page.name

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    date = datetime.now(timezone.utc).date().isoformat()
    slug = page.stem
    out_path = OUT_DIR / f"distribution-pack-{date}-{slug}.md"

    tweets = _tweet_variants(title=title, desc=desc, h1=h1, url=url)
    comments = _reddit_comment_variants(desc=desc, url=url)

    md = []
    md.append(f"# Distribution Pack — {page.name} (UTC {date})")
    md.append("")
    md.append(f"Generated: {iso_utc_now()}")
    md.append("")
    md.append("## Source-of-truth page data (verbatim from HTML)")
    md.append(f"- URL: {url}")
    md.append(f"- <title>: {title or '(missing)'}")
    md.append(f"- meta description: {desc or '(missing)'}")
    md.append(f"- first H1: {h1 or '(missing)'}")
    md.append("")

    md.append("## Twitter / X drafts (copy/paste; do not post automatically)")
    for i, t in enumerate(tweets, 1):
        md.append("")
        md.append(f"### Draft {i}")
        md.append(t)

    md.append("")
    md.append("## Reddit comment drafts (value-first; do not post automatically)")
    md.append("")
    md.append("Notes:")
    md.append("- Follow each subreddit’s rules on self-promo.")
    md.append("- Avoid medical advice (no dosing directions).")
    for i, c in enumerate(comments, 1):
        md.append("")
        md.append(f"### Comment {i}")
        md.append(c)

    md.append("")
    md.append("## Next: where to distribute")
    md.append("- If there’s an active thread asking for ‘what app / what tracker’, use a Reddit draft above.")
    md.append("- If Twitter is blocked, queue these drafts until TWITTER_API_KEY or browser relay is configured.")

    content = "\n".join(md) + "\n"

    # Avoid churn: only rewrite the pack if content actually changed.
    if out_path.exists():
        try:
            if out_path.read_text(encoding="utf-8", errors="replace") == content:
                print(f"distribution_pack:skip_unchanged:{out_path}")
                return 0
        except Exception:
            # If we can't read existing output, fall back to writing a fresh file.
            pass

    out_path.write_text(content, encoding="utf-8")
    print(f"distribution_pack:ok:{out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
