#!/usr/bin/env python3
"""Audit internal HTML links in the deployed static site.

Checks:
- For each href pointing to an on-site HTML page, confirm the target file exists.
- Handles:
  - Relative links: /foo.html, foo.html
  - Same-site absolute: https://jabbitapp.com/foo.html, https://jabbitapp.com/foo.html
- Ignores:
  - mailto:, tel:, javascript:
  - external domains
  - pure fragment links (#section)

Usage:
  python3 scripts/internal-link-audit.py           # human-readable
  python3 scripts/internal-link-audit.py --json   # machine-readable

Exit codes:
  0: ok
  1: broken links found
  2: configuration error
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
from datetime import datetime, timezone
from urllib.parse import urlparse

WS = pathlib.Path("/home/jabbit/.openclaw/workspace")
SITE_DIR = WS / "jabbitapp.com"

HREF_RE = re.compile(r"href\s*=\s*([\"'])(.*?)\1", re.IGNORECASE)


def iso_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def normalize_to_path(href: str) -> str | None:
    href = href.strip()
    if not href or href.startswith("#"):
        return None

    low = href.lower()
    if low.startswith(("mailto:", "tel:", "javascript:")):
        return None

    # Absolute URL?
    if low.startswith(("http://", "https://")):
        u = urlparse(href)
        if u.netloc not in ("jabbitapp.com", "www.jabbitapp.com"):
            return None
        path = u.path
    else:
        path = href

    # Strip fragment + query
    path = path.split("#", 1)[0].split("?", 1)[0]

    # Only validate html pages
    if not path.endswith(".html"):
        return None

    # Normalize leading /
    if path.startswith("/"):
        path = path[1:]

    return path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    if not SITE_DIR.exists():
        print(f"ERROR: missing site dir: {SITE_DIR}", file=sys.stderr)
        return 2

    html_files = sorted([p for p in SITE_DIR.glob("*.html") if p.is_file()])

    broken: list[dict] = []
    checked_links = 0

    for f in html_files:
        text = f.read_text(encoding="utf-8", errors="replace")
        for m in HREF_RE.finditer(text):
            href = m.group(2)
            rel = normalize_to_path(href)
            if rel is None:
                continue
            checked_links += 1
            target = SITE_DIR / rel
            if not target.exists():
                broken.append(
                    {
                        "file": f.name,
                        "href": href,
                        "normalized": rel,
                        "missing": str(target),
                    }
                )

    ok = len(broken) == 0
    out = {
        "ok": ok,
        "site_dir": str(SITE_DIR),
        "scanned_files": len(html_files),
        "checked_links": checked_links,
        "broken_count": len(broken),
        "broken": broken[:200],
        "ts": iso_now(),
    }

    if args.json:
        print(json.dumps(out, indent=2))
    else:
        print(f"internal_link_audit: files={out['scanned_files']} links={out['checked_links']} broken={out['broken_count']}")
        if not ok:
            for b in broken[:50]:
                print(f"  - {b['file']}: {b['href']} -> MISSING {b['normalized']}")

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
