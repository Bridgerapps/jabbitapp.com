#!/usr/bin/env python3
"""Generate sitemap.xml from the HTML files in this repo.

- Recurses into folders (research/, peptides/, guides/, news/, tools/...).
- Uses each page's <link rel="canonical"> as <loc>, so sitemap == canonicals.
- Skips noindex pages, 404.html and vendored/tooling dirs.
- <lastmod> = date of the last git commit touching the file (accurate), else mtime.
Site dir defaults to the repo root; override with JABBIT_SITE_DIR.
"""
from __future__ import annotations
import os, pathlib, re, subprocess
from datetime import datetime, timezone

SITE_DIR = pathlib.Path(os.environ.get("JABBIT_SITE_DIR", pathlib.Path(__file__).resolve().parent.parent))
OUT = SITE_DIR / "sitemap.xml"
SKIP = re.compile(r"^(node_modules|output|jabbit|jabbitapp\.com|docs|_includes|api|data|scripts|tools/asr)(/|$)")

def lastmod(p: pathlib.Path) -> str:
    try:
        d = subprocess.run(["git", "-C", str(SITE_DIR), "log", "-1", "--format=%cs", "--", str(p.relative_to(SITE_DIR))],
                           capture_output=True, text=True, check=True).stdout.strip()
        if d:
            return d
    except Exception:
        pass
    return datetime.fromtimestamp(p.stat().st_mtime, tz=timezone.utc).date().isoformat()

def main() -> None:
    seen: dict[str, str] = {}
    for p in sorted(SITE_DIR.rglob("*.html")):
        rel = p.relative_to(SITE_DIR).as_posix()
        if SKIP.match(rel) or rel == "404.html":
            continue
        h = p.read_text(encoding="utf-8", errors="ignore")
        if re.search(r'<meta[^>]+name="robots"[^>]+noindex|<meta[^>]+noindex[^>]+name="robots"', h):
            continue
        m = re.search(r'<link[^>]*rel="canonical"[^>]*href="([^"]+)"|<link[^>]*href="([^"]+)"[^>]*rel="canonical"', h)
        if not m:
            continue
        loc = m.group(1) or m.group(2)
        if not loc.startswith("https://jabbitapp.com"):
            continue
        lm = lastmod(p)
        seen[loc] = max(seen.get(loc, lm), lm)
    lines = ['<?xml version="1.0" encoding="UTF-8"?>', '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
    for loc in sorted(seen, key=lambda u: (u != "https://jabbitapp.com/", u)):
        lines += ["  <url>", f"    <loc>{loc}</loc>", f"    <lastmod>{seen[loc]}</lastmod>", "  </url>"]
    lines.append("</urlset>")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {OUT} ({len(seen)} urls)")

if __name__ == "__main__":
    main()
