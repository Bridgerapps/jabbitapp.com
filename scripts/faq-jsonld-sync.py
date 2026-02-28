#!/usr/bin/env python3
"""Sync FAQPage JSON-LD blocks for any HTML pages containing <dl class="faq">.

Why:
- We already have a per-file tool (faqpage_jsonld_from_dl.py), but it’s easy to forget.
- This script makes FAQ JSON-LD idempotent and batchable, so it can be wired into
  site-sync + health checks.

Behavior:
- Scans a root directory (default: <workspace>/jabbitapp.com) for .html files.
- For files that contain FAQ dt/dd pairs in a <dl class="faq">, it ensures a
  <script type="application/ld+json" id="faq-jsonld">…</script> block exists and
  matches the extracted FAQ content.

Exit codes:
- 0: ok
- 1: changes needed (only in --check mode)
- 2: fatal error
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path


# Local import (same directory).
try:
    import faqpage_jsonld_from_dl as faq
except Exception as e:  # pragma: no cover
    print(f"faq-jsonld-sync: failed_import faqpage_jsonld_from_dl: {e}", file=sys.stderr)
    raise


@dataclass
class FileResult:
    path: str
    pairs: int | None
    changed: bool
    error: str | None = None


def _iter_html_files(root: Path):
    for p in sorted(root.rglob("*.html")):
        # Skip hidden directories/files just in case (relative to root).
        try:
            rel = p.relative_to(root)
        except Exception:
            rel = p
        if any(part.startswith(".") for part in rel.parts):
            continue
        yield p


def sync_one(path: Path, *, script_id: str, indent: int) -> tuple[str | None, FileResult]:
    try:
        html = path.read_text(encoding="utf-8")
    except Exception as e:
        return None, FileResult(path=str(path), pairs=None, changed=False, error=f"read_failed:{e}")

    try:
        pairs = faq.extract_faq_pairs(html)
    except Exception as e:
        return None, FileResult(path=str(path), pairs=None, changed=False, error=f"parse_failed:{e}")

    if not pairs:
        # No FAQ content → nothing to do.
        return html, FileResult(path=str(path), pairs=0, changed=False, error=None)

    try:
        data = faq.build_faqpage_jsonld(pairs)
        script_block = faq.render_jsonld_script(data, indent=indent, script_id=script_id)
        new_html, _ = faq._replace_or_insert_script(html, script_id=script_id, script_block=script_block)
    except Exception as e:
        return html, FileResult(path=str(path), pairs=len(pairs), changed=False, error=f"build_failed:{e}")

    changed = new_html != html
    return new_html, FileResult(path=str(path), pairs=len(pairs), changed=changed, error=None)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--root",
        default=None,
        help="Root directory to scan (default: <workspace>/jabbitapp.com).",
    )
    ap.add_argument(
        "--script-id",
        default="faq-jsonld",
        help='Script tag id to manage (default: "faq-jsonld").',
    )
    ap.add_argument(
        "--indent",
        type=int,
        default=2,
        help="JSON indent level to render (default: 2).",
    )
    ap.add_argument(
        "--check",
        action="store_true",
        help="Do not write; exit non-zero if changes would be made.",
    )
    ap.add_argument(
        "--json",
        action="store_true",
        help="Emit a JSON summary to stdout.",
    )
    args = ap.parse_args(argv)

    ws = Path(os.environ.get("WORKSPACE", "/home/jabbit/.openclaw/workspace"))
    root = Path(args.root) if args.root else (ws / "jabbitapp.com")

    if not root.exists() or not root.is_dir():
        print(f"faq-jsonld-sync: root_not_found {root}", file=sys.stderr)
        return 2

    results: list[FileResult] = []

    for p in _iter_html_files(root):
        new_html, r = sync_one(p, script_id=args.script_id, indent=args.indent)
        results.append(r)

        if r.error:
            continue

        if r.changed and not args.check:
            try:
                assert new_html is not None
                p.write_text(new_html, encoding="utf-8")
            except Exception as e:
                r.error = f"write_failed:{e}"
                r.changed = False

    files_with_faq = sum(1 for r in results if (r.pairs or 0) > 0)
    changed_count = sum(1 for r in results if r.changed)
    error_count = sum(1 for r in results if r.error)

    ok = error_count == 0 and (changed_count == 0 or not args.check)

    if args.json:
        out = {
            "ok": ok,
            "root": str(root),
            "files_scanned": len(results),
            "files_with_faq": files_with_faq,
            "changed_count": changed_count,
            "error_count": error_count,
            "changed_files": [r.path for r in results if r.changed],
            "error_files": [{"path": r.path, "error": r.error} for r in results if r.error],
        }
        sys.stdout.write(json.dumps(out, indent=2) + "\n")

    # In --check mode, changes imply non-zero exit.
    if args.check and changed_count > 0:
        return 1

    if error_count > 0:
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
