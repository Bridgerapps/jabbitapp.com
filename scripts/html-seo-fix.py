#!/usr/bin/env python3
"""Auto-fix basic on-page SEO issues for static HTML pages.

Current scope (intentionally narrow):
- Add missing <link rel="canonical" ...> tags.

Why:
- html-seo-audit.sh can detect issues, but manual fixes get repetitive.
- Canonical tags reduce duplicate indexing + help health-check stay green.

Safe behavior:
- Only edits files that *lack* any rel="canonical" tag.
- Inserts the canonical link immediately before </head>.

Usage:
  python3 scripts/html-seo-fix.py
  python3 scripts/html-seo-fix.py --dry-run
  python3 scripts/html-seo-fix.py --site-dir /path/to/site --base https://example.com/
"""

from __future__ import annotations

import argparse
import pathlib

DEFAULT_SITE_DIR = pathlib.Path("/home/jabbit/.openclaw/workspace/jabbitapp.com")
DEFAULT_BASE = "https://jabbitapp.com/"


def ensure_trailing_slash(s: str) -> str:
    return s if s.endswith("/") else s + "/"


def add_canonical_if_missing(html: str, canonical_href: str) -> tuple[str, bool]:
    lowered = html.lower()
    if 'rel="canonical"' in lowered or "rel='canonical'" in lowered:
        return html, False

    insert = f"  <link rel=\"canonical\" href=\"{canonical_href}\">\n"

    # Insert before </head> if present.
    idx = lowered.find("</head>")
    if idx != -1:
        return html[:idx] + insert + html[idx:], True

    # Fallback: prepend at top if head tag is missing/malformed.
    return insert + html, True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--site-dir", default=str(DEFAULT_SITE_DIR))
    ap.add_argument("--base", default=DEFAULT_BASE)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    site_dir = pathlib.Path(args.site_dir)
    base = ensure_trailing_slash(args.base)

    if not site_dir.exists():
        raise SystemExit(f"site-dir does not exist: {site_dir}")

    html_files = sorted([p for p in site_dir.glob("*.html") if p.is_file()])
    changed: list[pathlib.Path] = []

    for p in html_files:
        canonical = base + p.name
        html = p.read_text(encoding="utf-8")
        new_html, did = add_canonical_if_missing(html, canonical)
        if did:
            changed.append(p)
            if not args.dry_run:
                p.write_text(new_html, encoding="utf-8")

    print(f"html_seo_fix: scanned={len(html_files)} changed={len(changed)} dry_run={args.dry_run}")
    for p in changed:
        print(f"  fixed: missing_canonical -> {p.name}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
