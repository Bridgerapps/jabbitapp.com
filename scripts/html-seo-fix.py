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
- Never emits trailing slashes on folder URLs (vercel.json trailingSlash:false).
  Root stays https://jabbitapp.com/ ; folders are https://jabbitapp.com/research
  (not .../research/). index.html maps to the extensionless folder URL.

Usage:
  python3 scripts/html-seo-fix.py
  python3 scripts/html-seo-fix.py --dry-run
  python3 scripts/html-seo-fix.py --site-dir /path/to/site --base https://example.com
"""

from __future__ import annotations

import argparse
import pathlib
import re

DEFAULT_SITE_DIR = pathlib.Path("/home/jabbit/.openclaw/workspace/jabbitapp.com")
DEFAULT_BASE = "https://jabbitapp.com"
SKIP = re.compile(
    r"^(node_modules|output|jabbit|jabbitapp\.com|docs|_includes|api|data|scripts|tools/asr)(/|$)"
)


def normalize_base(s: str) -> str:
    """Site origin with no trailing slash (except we treat bare origin separately)."""
    return s.rstrip("/")


def canonical_for(rel: pathlib.Path, base: str) -> str:
    """Build a canonical URL for a site-relative HTML path.

    trailingSlash:false — folder index pages use extensionless URLs without a
    trailing slash. Only the site root keeps a trailing slash.
    """
    parts = rel.as_posix()
    if parts == "index.html":
        return base + "/"
    if parts.endswith("/index.html"):
        folder = parts[: -len("/index.html")]
        return f"{base}/{folder}"
    return f"{base}/{parts}"


def add_canonical_if_missing(html: str, canonical_href: str) -> tuple[str, bool]:
    lowered = html.lower()
    if 'rel="canonical"' in lowered or "rel='canonical'" in lowered:
        return html, False

    insert = f'  <link rel="canonical" href="{canonical_href}">\n'

    idx = lowered.find("</head>")
    if idx != -1:
        return html[:idx] + insert + html[idx:], True

    return insert + html, True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--site-dir", default=str(DEFAULT_SITE_DIR))
    ap.add_argument("--base", default=DEFAULT_BASE)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    site_dir = pathlib.Path(args.site_dir)
    base = normalize_base(args.base)

    if not site_dir.exists():
        raise SystemExit(f"site-dir does not exist: {site_dir}")

    html_files = sorted(
        p
        for p in site_dir.rglob("*.html")
        if p.is_file() and not SKIP.match(p.relative_to(site_dir).as_posix())
    )
    changed: list[pathlib.Path] = []

    for p in html_files:
        rel = p.relative_to(site_dir)
        if rel.as_posix() == "404.html":
            continue
        canonical = canonical_for(rel, base)
        # Guard: never write folder URLs with a trailing slash (root excepted).
        if canonical != base + "/" and canonical.endswith("/"):
            raise SystemExit(f"refusing trailing-slash folder URL: {canonical}")
        html = p.read_text(encoding="utf-8")
        new_html, did = add_canonical_if_missing(html, canonical)
        if did:
            changed.append(p)
            if not args.dry_run:
                p.write_text(new_html, encoding="utf-8")

    print(
        f"html_seo_fix: scanned={len(html_files)} changed={len(changed)} dry_run={args.dry_run}"
    )
    for p in changed:
        print(f"  fixed: missing_canonical -> {p.relative_to(site_dir).as_posix()}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
