#!/usr/bin/env python3
"""Generate SEO effectiveness report focused on subscriptions.

Primary goal: app subscriptions.
Primary web KPI chain: Organic Visits -> App Store Clicks -> App Store Units.

This report intentionally uses incubation windows so pages get enough time to rank
before we mark them as losers.
"""

from __future__ import annotations

import json
import subprocess
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone, timedelta
from pathlib import Path

WS = Path('/home/jabbit/.openclaw/workspace')
ANALYTICS = Path('/home/jabbit/analytics/data.json')
OUT_DIR = WS / 'docs'

SEARCH_REF_MARKERS = (
    'google.', 'bing.', 'duckduckgo.', 'search.yahoo.', 'yahoo.', 'ecosia.', 'brave.'
)

INCUBATE_DAYS = 21        # do not kill pages before this
MATURE_DAYS = 45          # stronger keep/fix/kill decisions after this


@dataclass
class PageStat:
    url: str
    age_days: int | None
    visits_7d: int = 0
    visits_30d: int = 0
    organic_7d: int = 0
    organic_30d: int = 0
    clicks_7d: int = 0
    clicks_30d: int = 0

    @property
    def ctr_7d(self) -> float:
        return (self.clicks_7d / self.visits_7d) if self.visits_7d else 0.0


def normalize_page(p: str) -> str:
    p = (p or '/').strip()
    if not p.startswith('/'):
        p = '/' + p
    return p


def is_organic(ref: str) -> bool:
    r = (ref or '').lower()
    return any(m in r for m in SEARCH_REF_MARKERS)


def load_events() -> list[dict]:
    if not ANALYTICS.exists():
        return []
    try:
        j = json.loads(ANALYTICS.read_text())
    except Exception:
        return []
    return j.get('events', []) or []


def page_file_candidates() -> list[Path]:
    pages = []
    pages.extend(sorted(WS.glob('*.html')))
    pages.extend(sorted((WS / 'guides').glob('*.html')))
    return pages


def page_url_from_file(p: Path) -> str:
    if p.parent.name == 'guides':
        if p.name == 'index.html':
            return '/guides/'
        return f"/guides/{p.stem}.html"
    if p.name == 'index.html':
        return '/'
    return f"/{p.name}"


def git_first_seen_iso(path: Path) -> str | None:
    rel = str(path.relative_to(WS))
    cmd = ['git', '-C', str(WS), 'log', '--diff-filter=A', '--follow', '--format=%aI', '--', rel]
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        return None
    lines = [x.strip() for x in p.stdout.splitlines() if x.strip()]
    return lines[-1] if lines else None


def age_days(path: Path, now: datetime) -> int | None:
    iso = git_first_seen_iso(path)
    if not iso:
        return None
    try:
        dt = datetime.fromisoformat(iso.replace('Z', '+00:00'))
        return max(0, (now - dt.astimezone(timezone.utc)).days)
    except Exception:
        return None


def classify(ps: PageStat) -> str:
    age = ps.age_days if ps.age_days is not None else 999

    if age < INCUBATE_DAYS:
        return 'INCUBATING (hold, keep indexed)'

    if ps.organic_30d >= 20 and ps.clicks_30d == 0:
        return 'FIX CTA (traffic but no click intent)'

    if ps.organic_30d < 5 and ps.age_days is not None and ps.age_days >= MATURE_DAYS and ps.clicks_30d == 0:
        return 'REWRITE/PRUNE candidate (mature, low signal)'

    if ps.ctr_7d >= 0.05 and ps.organic_30d < 20:
        return 'AMPLIFY (good click intent, needs distribution/internal links)'

    if ps.clicks_30d > 0:
        return 'KEEP + iterate headline/CTA'

    return 'MONITOR'


def load_appstore_units_latest() -> tuple[int | None, str | None]:
    # Reuse existing report parser via direct execution to avoid duplicate logic.
    try:
        p = subprocess.run(
            ['python3', str(WS / 'scripts' / 'appstore-sales.py')],
            capture_output=True,
            text=True,
            timeout=45,
        )
        out = p.stdout or ''
        units = None
        report_date = None
        for line in out.splitlines():
            s = line.strip().lower()
            if s.startswith('units:'):
                try:
                    units = int(line.split(':', 1)[1].strip())
                except Exception:
                    pass
            if 'report date (pt):' in s:
                report_date = line.split(':', 1)[1].strip()
        return units, report_date
    except Exception:
        return None, None


def main() -> int:
    now = datetime.now(timezone.utc)
    start_7 = now - timedelta(days=7)
    start_30 = now - timedelta(days=30)

    events = load_events()

    page_stats: dict[str, PageStat] = {}
    for f in page_file_candidates():
        url = page_url_from_file(f)
        page_stats[url] = PageStat(url=url, age_days=age_days(f, now))

    # Ensure pages discovered only via events also appear.
    for e in events:
        url = normalize_page(e.get('page') or '/')
        page_stats.setdefault(url, PageStat(url=url, age_days=None))

    for e in events:
        ts = e.get('timestamp')
        if not ts:
            continue
        try:
            dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
        except Exception:
            continue

        url = normalize_page(e.get('page') or '/')
        ps = page_stats.setdefault(url, PageStat(url=url, age_days=None))

        event = (e.get('event') or 'pageview').lower()
        ref = e.get('ref') or ''

        if event == 'pageview':
            if dt >= start_30:
                ps.visits_30d += 1
                if is_organic(ref):
                    ps.organic_30d += 1
            if dt >= start_7:
                ps.visits_7d += 1
                if is_organic(ref):
                    ps.organic_7d += 1

        elif event == 'app_store_click':
            if dt >= start_30:
                ps.clicks_30d += 1
            if dt >= start_7:
                ps.clicks_7d += 1

    pages = sorted(page_stats.values(), key=lambda x: (x.clicks_30d, x.organic_30d, x.visits_30d), reverse=True)

    total_org_7 = sum(p.organic_7d for p in pages)
    total_click_7 = sum(p.clicks_7d for p in pages)
    total_org_30 = sum(p.organic_30d for p in pages)
    total_click_30 = sum(p.clicks_30d for p in pages)

    ctr_7 = (total_click_7 / total_org_7) if total_org_7 else 0.0
    ctr_30 = (total_click_30 / total_org_30) if total_org_30 else 0.0

    units, report_date = load_appstore_units_latest()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / f"seo-effectiveness-{now.date().isoformat()}.md"

    lines = []
    lines.append(f"# SEO Effectiveness Report — {now.date().isoformat()}\n")
    lines.append("Goal alignment: **Organic visits -> App Store clicks -> App Store units/subscriptions**\n")

    lines.append("## Rollup")
    lines.append(f"- Organic visits (7d): **{total_org_7}**")
    lines.append(f"- App Store clicks (7d): **{total_click_7}**")
    lines.append(f"- Organic->Click CTR (7d): **{ctr_7:.1%}**")
    lines.append(f"- Organic visits (30d): **{total_org_30}**")
    lines.append(f"- App Store clicks (30d): **{total_click_30}**")
    lines.append(f"- Organic->Click CTR (30d): **{ctr_30:.1%}**")
    if units is not None:
        lines.append(f"- Latest App Store units: **{units}**")
    if report_date:
        lines.append(f"- App Store report date: **{report_date}**")

    lines.append("\n## Ranking-time policy (to avoid premature kills)")
    lines.append(f"- **Incubation window:** hold pages for at least **{INCUBATE_DAYS} days** before kill/prune decisions.")
    lines.append(f"- **Mature window:** use stronger keep/fix/kill rules after **{MATURE_DAYS} days**.")
    lines.append("- During incubation: improve internal linking + distribution, but do not prune for low traffic.")

    lines.append("\n## Page-level decisions (30d)")
    lines.append("| Page | Age (d) | Organic 30d | Clicks 30d | CTR 7d | Decision |")
    lines.append("|---|---:|---:|---:|---:|---|")

    for p in pages[:40]:
        age = p.age_days if p.age_days is not None else 'n/a'
        lines.append(
            f"| `{p.url}` | {age} | {p.organic_30d} | {p.clicks_30d} | {p.ctr_7d:.1%} | {classify(p)} |"
        )

    top_amplify = [p for p in pages if classify(p).startswith('AMPLIFY')][:5]
    top_fix = [p for p in pages if classify(p).startswith('FIX CTA')][:5]
    top_prune = [p for p in pages if classify(p).startswith('REWRITE/PRUNE')][:5]

    lines.append("\n## Action queue")
    if top_amplify:
        lines.append("- **Amplify now:** " + ", ".join(f"`{p.url}`" for p in top_amplify))
    if top_fix:
        lines.append("- **Fix CTA/content intent:** " + ", ".join(f"`{p.url}`" for p in top_fix))
    if top_prune:
        lines.append("- **Rewrite/Prune candidates (only mature pages):** " + ", ".join(f"`{p.url}`" for p in top_prune))
    if not (top_amplify or top_fix or top_prune):
        lines.append("- No strong outliers yet; keep data collection + incubation policy.")

    out.write_text("\n".join(lines) + "\n", encoding='utf-8')
    print(str(out))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
