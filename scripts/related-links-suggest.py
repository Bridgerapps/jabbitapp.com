#!/usr/bin/env python3
"""Suggest (or auto-create) missing related-links rules.

Why:
- We want most pages under jabbitapp.com/ to have a small, consistent internal-links block.
- Manually maintaining data/seo/related-links.json is repetitive.

This script:
- Finds HTML pages missing from data/seo/related-links.json
- Suggests a minimal set of internal links based on filename heuristics

Usage:
  python3 scripts/related-links-suggest.py --json
  python3 scripts/related-links-suggest.py --check          # exit 2 if suggestions exist
  python3 scripts/related-links-suggest.py --write --json   # append suggested rules

Exit codes:
  0 ok
  2 suggestions exist (in --check mode)
  3 config error
"""

from __future__ import annotations

import argparse
import json
import pathlib
from datetime import datetime, timezone

WS = pathlib.Path("/home/jabbit/.openclaw/workspace")
SITE_DIR = WS / "jabbitapp.com"
RULES_FILE = WS / "data" / "seo" / "related-links.json"

# Pages that intentionally do NOT get a related-links block (different layout / already acts as hub).
EXEMPT_FILES = {
    "index.html",
}


def iso_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def uniq_by_href(links: list[dict], limit: int = 3) -> list[dict]:
    out: list[dict] = []
    seen: set[str] = set()
    for l in links:
        href = (l.get("href") or "").strip()
        text = (l.get("text") or "").strip()
        if not href or not text:
            continue
        if href in seen:
            continue
        seen.add(href)
        out.append({"href": href, "text": text})
        if len(out) >= limit:
            break
    return out


def suggest_links(filename: str) -> list[dict]:
    fn = filename.lower()
    links: list[dict] = []

    # Global conversion pages
    if fn != "glp1-injection-tracker.html":
        links.append({
            "href": "/glp1-injection-tracker.html",
            "text": "GLP-1 injection tracker (log doses + reminders)",
        })
    if fn != "glp1-dosing-schedule.html" and fn.startswith("glp"):
        links.append({
            "href": "/glp1-dosing-schedule.html",
            "text": "GLP-1 dosing schedules (reference for what to log)",
        })

    # Competitor/alternative pages are still GLP-1 intent; treat them like GLP pages.
    if "shotsy" in fn:
        links.append({
            "href": "/glp1-dosing-schedule.html",
            "text": "GLP-1 dosing schedules (reference for what to log)",
        })
        links.append({
            "href": "/glp-1-injection-tracking-guide.html",
            "text": "GLP-1 injection tracking guide (rotation + logging)",
        })

    # Cluster-specific
    if "injection" in fn and fn != "glp-1-injection-tracking-guide.html":
        links.append({
            "href": "/glp-1-injection-tracking-guide.html",
            "text": "GLP-1 injection tracking guide (rotation + logging)",
        })

    if "constipation" in fn:
        links.append({
            "href": "/glp1-constipation-guide.html",
            "text": "GLP-1 constipation guide (practical relief + red flags)",
        })

    if "side-effects" in fn:
        links.append({
            "href": "/glp-1-side-effects-guide.html",
            "text": "GLP-1 side effects guide (what to expect + when to call)",
        })

    # GLP-1 medication pages that don't start with "glp" in filename.
    if any(k in fn for k in ["tirzepatide", "semaglutide", "ozempic", "wegovy", "mounjaro", "zepbound", "compounded"]):
        if fn != "glp-1-side-effects-guide.html":
            links.append({
                "href": "/glp-1-side-effects-guide.html",
                "text": "GLP-1 side effects guide (what to expect + when to call)",
            })
        if fn != "glp1-dosing-schedule.html":
            links.append({
                "href": "/glp1-dosing-schedule.html",
                "text": "GLP-1 dosing schedules (reference for what to log)",
            })

    if ("stress" in fn or "hrv" in fn) and fn != "glp1-stress-anxiety-hrv-guide.html":
        links.append({
            "href": "/glp1-stress-anxiety-hrv-guide.html",
            "text": "Stress/HRV on GLP-1 (what to track + patterns)",
        })

    # Peptides cluster
    if "peptide" in fn or fn.startswith(("bpc-", "tb-")):
        if fn != "peptide-reconstitution-guide.html":
            links.append({
                "href": "/peptide-reconstitution-guide.html",
                "text": "Peptide reconstitution guide (step-by-step)",
            })
        if fn != "peptide-storage-stability-guide.html":
            links.append({
                "href": "/peptide-storage-stability-guide.html",
                "text": "Peptide storage & stability guide (what matters)",
            })
        if fn != "peptide-site-rotation-guide.html":
            links.append({
                "href": "/peptide-site-rotation-guide.html",
                "text": "Peptide site rotation guide (practical rotation patterns)",
            })

    return uniq_by_href(links, limit=3)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true", help="Print JSON output")
    ap.add_argument("--check", action="store_true", help="Exit non-zero if suggestions exist")
    ap.add_argument("--write", action="store_true", help="Append suggested rules to related-links.json")
    ap.add_argument("--limit", type=int, default=200, help="Max suggested rules")
    args = ap.parse_args()

    if not SITE_DIR.exists():
        print(f"ERROR: missing site dir: {SITE_DIR}")
        return 3
    if not RULES_FILE.exists():
        print(f"ERROR: missing rules file: {RULES_FILE}")
        return 3

    doc = json.loads(RULES_FILE.read_text(encoding="utf-8"))
    rules = doc.get("rules") or []
    covered = {r.get("file") for r in rules if r.get("file")}

    html_files = sorted([p.name for p in SITE_DIR.glob("*.html") if p.is_file()])
    missing = [fn for fn in html_files if fn not in covered and fn not in EXEMPT_FILES]

    suggestions: list[dict] = []
    for fn in missing[: args.limit]:
        links = suggest_links(fn)
        # Only suggest if we can produce at least 2 useful links.
        if len(links) >= 2:
            suggestions.append({"file": fn, "links": links})

    if args.write and suggestions:
        # Append suggestions (idempotent-ish: we only consider uncovered files)
        rules.extend(suggestions)
        doc["rules"] = rules
        doc["updated"] = iso_now()
        RULES_FILE.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    out = {
        "ok": True,
        "site_dir": str(SITE_DIR),
        "rules_file": str(RULES_FILE),
        "html_files": len(html_files),
        "covered": len(covered),
        "exempt_files": sorted(EXEMPT_FILES),
        "missing_count": len(missing),
        "missing": missing,
        "suggested_count": len(suggestions),
        "suggestions": suggestions,
        "ts": iso_now(),
    }

    if args.json:
        print(json.dumps(out, indent=2, ensure_ascii=False))
    else:
        print(f"related_links_suggest: html={out['html_files']} covered={out['covered']} missing={len(missing)} suggested={out['suggested_count']}")
        for s in suggestions[:20]:
            print(f"  - {s['file']}: {', '.join([l['href'] for l in s['links']])}")

    # Coverage check: fail if there are *any* uncovered pages (after exemptions).
    if args.check and (len(missing) > 0):
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
