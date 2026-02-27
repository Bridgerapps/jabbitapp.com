#!/usr/bin/env python3
"""Generate jabbitapp.com/sitemap.xml from the local HTML files.

Why:
- robots.txt explicitly points crawlers to https://jabbitapp.com/sitemap.xml
- Keeping sitemap URLs aligned to real on-disk pages avoids shipping 404s.

This script is intentionally dependency-free.
"""

from __future__ import annotations

import pathlib
from datetime import datetime, timezone

SITE_DIR = pathlib.Path("/home/jabbit/.openclaw/workspace/jabbitapp.com")
OUT = SITE_DIR / "sitemap.xml"
BASE = "https://jabbitapp.com/"


def lastmod_utc_date(p: pathlib.Path) -> str:
    ts = p.stat().st_mtime
    return datetime.fromtimestamp(ts, tz=timezone.utc).date().isoformat()


def main() -> None:
    pages = sorted([p for p in SITE_DIR.glob("*.html") if p.is_file()])
    if not pages:
        raise SystemExit(f"No .html files found in {SITE_DIR}")

    lines: list[str] = []
    lines.append('<?xml version="1.0" encoding="UTF-8"?>')
    lines.append('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')

    for p in pages:
        fname = p.name
        loc = BASE + fname
        priority = "1.0" if fname == "index.html" else "0.8"
        changefreq = "monthly"
        lastmod = lastmod_utc_date(p)

        lines.append("  <url>")
        lines.append(f"    <loc>{loc}</loc>")
        lines.append(f"    <lastmod>{lastmod}</lastmod>")
        lines.append(f"    <changefreq>{changefreq}</changefreq>")
        lines.append(f"    <priority>{priority}</priority>")
        lines.append("  </url>")

    lines.append("</urlset>")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"sitemap:ok:{OUT} urls={len(pages)}")


if __name__ == "__main__":
    main()
