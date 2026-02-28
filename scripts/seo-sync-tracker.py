#!/usr/bin/env python3
"""Sync data/seo/page-tracker.json with the deployed static site.

Problem this fixes (reliability + autonomy):
- We keep adding new /jabbitapp.com/*.html pages, but page-tracker.json drifts.
- Drift breaks scripts like scripts/check-seo-topic.sh and creates duplicate-topic risk.

Behavior:
- Treat /home/jabbit/.openclaw/workspace/jabbitapp.com/*.html as source of truth.
- Maintain existing topic entries (do not rename topics).
- Add missing entries for any HTML file not present in the tracker (by filename match).
- Update total_pages.
- IMPORTANT: Idempotent — do NOT rewrite the tracker (or bump last_updated) when no
  changes are required.

Notes:
- Conservative: it will NOT delete entries; it only adds + updates counts.

Usage:
  python3 scripts/seo-sync-tracker.py
  python3 scripts/seo-sync-tracker.py --dry-run
"""

from __future__ import annotations

import argparse
import copy
import json
import pathlib
from datetime import datetime, timezone

WS = pathlib.Path("/home/jabbit/.openclaw/workspace")
SITE_DIR = WS / "jabbitapp.com"
TRACKER = WS / "data" / "seo" / "page-tracker.json"


def iso_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def created_date_from_mtime(p: pathlib.Path) -> str:
    return datetime.fromtimestamp(p.stat().st_mtime, tz=timezone.utc).date().isoformat()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not SITE_DIR.exists():
        raise SystemExit(f"missing site dir: {SITE_DIR}")

    html_files = sorted([p for p in SITE_DIR.glob("*.html") if p.is_file()])

    tracker = {"last_updated": "", "total_pages": 0, "topics": [], "suggested_topics": []}
    if TRACKER.exists():
        tracker = json.loads(TRACKER.read_text(encoding="utf-8"))

    orig = copy.deepcopy(tracker)

    topics: list[dict] = list(tracker.get("topics") or [])
    existing_by_filename = {t.get("filename"): t for t in topics if t.get("filename")}

    added = 0
    for p in html_files:
        if p.name == "index.html":
            continue
        if p.name in existing_by_filename:
            continue

        topics.append(
            {
                "topic": p.stem,
                "filename": p.name,
                "created": created_date_from_mtime(p),
            }
        )
        added += 1

    total_pages = len([p for p in html_files if p.is_file() and p.name != "index.html"])

    tracker["topics"] = topics
    tracker["total_pages"] = total_pages

    changed = False
    if (not TRACKER.exists()) or added > 0:
        changed = True
    if orig.get("total_pages") != total_pages:
        changed = True

    if changed:
        tracker["last_updated"] = iso_now()

    if (not args.dry_run) and changed:
        TRACKER.parent.mkdir(parents=True, exist_ok=True)
        TRACKER.write_text(json.dumps(tracker, indent=2, sort_keys=False) + "\n", encoding="utf-8")

    print(
        json.dumps(
            {
                "ok": True,
                "site_dir": str(SITE_DIR),
                "tracker": str(TRACKER),
                "html_files": len(html_files),
                "total_pages": total_pages,
                "topics_entries": len(topics),
                "added": added,
                "changed": changed,
                "dry_run": bool(args.dry_run),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
