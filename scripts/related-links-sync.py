#!/usr/bin/env python3
"""Inject (or update) a small "Related" internal-links block across site pages.

Why:
- Internal links tighten crawl paths and push high-intent users into conversion pages.
- Doing this manually is repetitive + error-prone.

Source of truth:
- data/seo/related-links.json

Behavior:
- For each rule, insert a <section id="related-links">…</section> block.
- Idempotent: if the section already exists, replace it.
- Placement:
  1) Before <div class="source"> if present, else
  2) Before </body>

Usage:
  python3 scripts/related-links-sync.py --check   # no writes; exits non-zero if changes needed
  python3 scripts/related-links-sync.py           # writes in-place
  python3 scripts/related-links-sync.py --json    # prints JSON summary
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
from datetime import datetime, timezone

WS = pathlib.Path("/home/jabbit/.openclaw/workspace")
SITE_DIR = WS / "jabbitapp.com"
RULES_FILE = WS / "data" / "seo" / "related-links.json"

SECTION_RE = re.compile(
    r"\n\s*<section\s+id=\"related-links\"[^>]*>.*?</section>\s*",
    re.IGNORECASE | re.DOTALL,
)


def iso_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def build_section(links: list[dict]) -> str:
    # Minimal styling; rely on page CSS where available.
    items = "\n".join(
        [
            f"    <li><a href=\"{l['href']}\">{l['text']}</a></li>"
            for l in links
            if l.get("href") and l.get("text")
        ]
    )
    return (
        "  <section id=\"related-links\">\n"
        "    <h2>Related</h2>\n"
        "    <ul>\n"
        f"{items}\n"
        "    </ul>\n"
        "  </section>\n"
    )


def place_section(html: str, section_html: str) -> tuple[str, str]:
    """Return (new_html, placement)"""
    # If already present, replace
    if SECTION_RE.search(html):
        # SECTION_RE includes the leading newline/whitespace before the section; add back a
        # single newline so repeated runs don’t accumulate blank lines.
        return (SECTION_RE.sub("\n" + section_html, html, count=1), "replaced")

    # Prefer before sources
    # NOTE: avoid using "\\b" after a quote; it doesn't match reliably.
    # We want to match: <div class="source"> (or with extra attrs) at the start of a line.
    m = re.search(r"\n\s*<div\s+class=\"source\"(?=[\s>])", html, flags=re.IGNORECASE)
    if m:
        idx = m.start()
        return (html[:idx] + "\n" + section_html + html[idx:], "inserted_before_source")

    # Fallback: before </body>
    m = re.search(r"</body\s*>", html, flags=re.IGNORECASE)
    if m:
        idx = m.start()
        return (html[:idx] + "\n" + section_html + html[idx:], "inserted_before_body_close")

    # Worst case: append
    return (html + "\n" + section_html, "appended")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="No writes; exit non-zero if changes needed")
    ap.add_argument("--json", action="store_true", help="Print JSON summary")
    args = ap.parse_args()

    if not SITE_DIR.exists():
        raise SystemExit(f"missing site dir: {SITE_DIR}")

    if not RULES_FILE.exists():
        raise SystemExit(f"missing rules file: {RULES_FILE}")

    rules_doc = json.loads(RULES_FILE.read_text(encoding="utf-8"))
    rules = rules_doc.get("rules") or []

    changed_files: list[str] = []
    results: list[dict] = []

    for r in rules:
        fn = r.get("file")
        links = r.get("links") or []
        if not fn:
            continue

        path = SITE_DIR / fn
        if not path.exists():
            results.append({"file": fn, "ok": False, "error": "missing_file"})
            continue

        old = path.read_text(encoding="utf-8")
        section = build_section(links)
        new, placement = place_section(old, section)
        ok = True

        if new != old:
            changed_files.append(fn)
            if not args.check:
                path.write_text(new, encoding="utf-8")
        else:
            placement = "noop"

        results.append({"file": fn, "ok": ok, "placement": placement, "changed": new != old})

    # Update rules metadata timestamp on write runs (keeps it honest)
    if (not args.check) and changed_files:
        rules_doc["updated"] = iso_now()
        RULES_FILE.write_text(json.dumps(rules_doc, indent=2, sort_keys=False) + "\n", encoding="utf-8")

    out = {
        "ok": True,
        "site_dir": str(SITE_DIR),
        "rules_file": str(RULES_FILE),
        "changed_count": len(changed_files),
        "changed_files": changed_files,
        "results": results,
        "mode": "check" if args.check else "write",
        "ts": iso_now(),
    }

    if args.json:
        print(json.dumps(out, indent=2))

    if args.check and changed_files:
        return 2

    # Treat missing files as failure in check mode
    if args.check and any((not x.get("ok")) for x in results):
        return 3

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
