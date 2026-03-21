#!/usr/bin/env python3
"""Run free, no-key marketing tests against jabbitapp.com.

Focus: subscription funnel readiness (visit -> App Store click).
Outputs:
- data/status/free-marketing-tests-YYYY-MM-DD.md (ephemeral)
- data/status/marketing-tests.json
"""

from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

WS = Path('/home/jabbit/.openclaw/workspace')
REPORT_DIR = WS / 'data' / 'status'
STATUS = WS / 'data' / 'status' / 'marketing-tests.json'

BASE = 'https://jabbitapp.com'
PAGES = [
    '/',
    '/shotsy-alternative.html',
    '/glp1-injection-tracker.html',
    '/zepbound-injection-tracker.html',
    '/guides/',
]


@dataclass
class PageResult:
    path: str
    http: int
    ttfb_s: float
    total_s: float
    title_len: int
    desc_len: int
    has_h1: bool
    has_appstore_link: bool
    appstore_link_count: int
    has_schema: bool
    has_noindex: bool
    has_tracking_js: bool


def curl_metrics(url: str) -> tuple[int, float, float, str]:
    cmd = [
        'curl', '-sS', '-L', '-D', '-',
        '-o', '/tmp/marketing-test-body.html',
        '-w', 'HTTP:%{http_code} TTFB:%{time_starttransfer} TOTAL:%{time_total}',
        url,
    ]
    p = subprocess.run(cmd, capture_output=True, text=True)
    out = p.stdout or ''
    m = re.search(r'HTTP:(\d+) TTFB:([0-9.]+) TOTAL:([0-9.]+)', out)
    http = int(m.group(1)) if m else 0
    ttfb = float(m.group(2)) if m else 0.0
    total = float(m.group(3)) if m else 0.0
    body = Path('/tmp/marketing-test-body.html').read_text(encoding='utf-8', errors='ignore') if Path('/tmp/marketing-test-body.html').exists() else ''
    return http, ttfb, total, body


def title_len(html: str) -> int:
    m = re.search(r'<title[^>]*>(.*?)</title>', html, flags=re.I | re.S)
    if not m:
        return 0
    return len(re.sub(r'\s+', ' ', m.group(1)).strip())


def desc_len(html: str) -> int:
    m = re.search(r'<meta[^>]+name=["\']description["\'][^>]*content=["\']([^"\']+)["\']', html, flags=re.I)
    if not m:
        return 0
    return len(m.group(1).strip())


def has_h1(html: str) -> bool:
    return bool(re.search(r'<h1\b', html, flags=re.I))


def has_schema(html: str) -> bool:
    return bool(re.search(r'<script[^>]+application/ld\+json', html, flags=re.I))


def has_noindex(html: str) -> bool:
    return bool(re.search(r'<meta[^>]+name=["\']robots["\'][^>]+content=["\'][^"\']*noindex', html, flags=re.I))


def appstore_links(html: str) -> list[str]:
    return re.findall(r'https://apps\.apple\.com[^"\'\s<]+', html, flags=re.I)


def tracking_js(html: str) -> bool:
    return '/assets/site.js' in html or '/api/track' in html


def score_page(r: PageResult) -> tuple[int, int]:
    checks = [
        r.http == 200,
        r.ttfb_s <= 1.2,
        r.total_s <= 2.5,
        30 <= r.title_len <= 65,
        110 <= r.desc_len <= 180,
        r.has_h1,
        r.has_appstore_link,
        r.has_schema,
        not r.has_noindex,
        r.has_tracking_js,
    ]
    return sum(1 for c in checks if c), len(checks)


def main() -> int:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    STATUS.parent.mkdir(parents=True, exist_ok=True)

    rows: list[PageResult] = []

    for path in PAGES:
        url = BASE.rstrip('/') + path
        http, ttfb, total, html = curl_metrics(url)
        links = appstore_links(html)
        rows.append(PageResult(
            path=path,
            http=http,
            ttfb_s=ttfb,
            total_s=total,
            title_len=title_len(html),
            desc_len=desc_len(html),
            has_h1=has_h1(html),
            has_appstore_link=bool(links),
            appstore_link_count=len(links),
            has_schema=has_schema(html),
            has_noindex=has_noindex(html),
            has_tracking_js=tracking_js(html),
        ))

    total_pass = 0
    total_checks = 0
    for r in rows:
        p, c = score_page(r)
        total_pass += p
        total_checks += c

    overall = (total_pass / total_checks) if total_checks else 0.0

    now = datetime.now(timezone.utc)
    report = REPORT_DIR / f'free-marketing-tests-{now.date().isoformat()}.md'

    lines = []
    lines.append(f"# Free Marketing Tests — {now.date().isoformat()}\n")
    lines.append("Goal: maximize **site visits -> App Store clicks -> installs/subscriptions** with free checks only.\n")
    lines.append(f"Overall pass rate: **{total_pass}/{total_checks} ({overall:.1%})**\n")
    lines.append("## Page checks")
    lines.append("| Page | HTTP | TTFB(s) | Total(s) | Title | Desc | H1 | AppStore link | Schema | Noindex | Tracking |")
    lines.append("|---|---:|---:|---:|---:|---:|:--:|:--:|:--:|:--:|:--:|")

    for r in rows:
        lines.append(
            f"| `{r.path}` | {r.http} | {r.ttfb_s:.2f} | {r.total_s:.2f} | {r.title_len} | {r.desc_len} | {'✅' if r.has_h1 else '❌'} | {'✅' if r.has_appstore_link else '❌'} ({r.appstore_link_count}) | {'✅' if r.has_schema else '❌'} | {'❌' if r.has_noindex else '✅'} | {'✅' if r.has_tracking_js else '❌'} |"
        )

    lines.append("\n## Action rubric")
    lines.append("- Speed fail (TTFB>1.2s or Total>2.5s): optimize page weight and server latency.")
    lines.append("- No App Store link: add one clear above-the-fold CTA.")
    lines.append("- Title/Description out of range: tighten SERP copy for click-through.")
    lines.append("- Missing schema: add structured data where relevant.")
    lines.append("- No tracking JS: fix instrumentation before making marketing decisions.")

    report.write_text('\n'.join(lines) + '\n', encoding='utf-8')

    status = {
        'generated_at_utc': now.isoformat(),
        'overall_pass_rate': overall,
        'total_pass': total_pass,
        'total_checks': total_checks,
        'report_path': str(report),
        'pages': [r.__dict__ for r in rows],
    }
    STATUS.write_text(json.dumps(status, indent=2), encoding='utf-8')

    print(str(report))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
