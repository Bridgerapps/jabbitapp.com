#!/usr/bin/env python3
"""Discover large peptide/biohacking-related subreddits and persist watchlist."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

WS = Path('/home/jabbit/.openclaw/workspace')
OUT_TXT = WS / 'data' / 'reddit' / 'research-peptide-biohacking-subs.txt'
OUT_JSON = WS / 'data' / 'reddit' / 'research-peptide-biohacking-subs.json'

QUERIES = [
    'research peptides', 'peptides', 'biohacking', 'longevity',
    'tirzepatide', 'semaglutide', 'retatrutide', 'metabolic health',
]

FALLBACK_SUBS = [
    'Biohackers', 'Peptides', 'ResearchPeptides', 'TirzepatideRX',
    'compoundedtirzepatide', 'Retatrutide', 'Semaglutide', 'Mounjaro',
    'Ozempic', 'Zepbound', 'Wegovy', 'GLP1microdosing', 'longevity'
]


def load_proxy() -> str:
    env = {}
    p = WS / 'scripts' / 'proxy.env'
    if not p.exists():
        return ''
    for raw in p.read_text(encoding='utf-8', errors='ignore').splitlines():
        s = raw.strip()
        if not s or s.startswith('#'):
            continue
        if s.startswith('export '):
            s = s[7:]
        if '=' not in s:
            continue
        k, v = s.split('=', 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    for k, v in list(env.items()):
        for rk, rv in env.items():
            v = v.replace('${' + rk + '}', rv)
        env[k] = v
    return env.get('DISCOVERY_REDDIT_PROXY_URL', '') or env.get('REDDIT_PROXY_URL', '')


def fetch_json(url: str, proxy: str) -> dict:
    cmd = ['curl', '-sS', '--max-time', '30', '-A', 'Mozilla/5.0', '-H', 'Accept: application/json']
    if proxy:
        cmd += ['-x', proxy]
    cmd += [url]
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0 or not p.stdout.strip().startswith('{'):
        return {}
    try:
        return json.loads(p.stdout)
    except Exception:
        return {}


def main() -> int:
    proxy = load_proxy()
    totals = {}

    for q in QUERIES:
        url = f'https://www.reddit.com/subreddits/search.json?q={q}&limit=100&include_over_18=off&raw_json=1'
        data = fetch_json(url, proxy)
        children = ((data.get('data') or {}).get('children') or [])
        for c in children:
            d = c.get('data') or {}
            name = (d.get('display_name') or '').strip()
            if not name or name.lower().startswith('u_'):
                continue
            subs = int(d.get('subscribers') or 0)
            if subs < 3000:
                continue
            key = name.lower()
            prev = totals.get(key)
            row = {
                'name': name,
                'subscribers': subs,
                'over18': bool(d.get('over18')),
                'public_description': (d.get('public_description') or '')[:220],
            }
            if (prev is None) or (subs > prev['subscribers']):
                totals[key] = row

    ranked = sorted(totals.values(), key=lambda x: x['subscribers'], reverse=True)

    # Keep relevant bucket (peptide/biohacking/longevity/metabolic language in name/desc).
    keep = []
    for r in ranked:
        blob = f"{r['name']} {r['public_description']}".lower()
        if any(k in blob for k in ['peptide', 'biohack', 'longevity', 'tirzep', 'semaglut', 'retatrut', 'glp', 'metabolic', 'weight loss']):
            keep.append(r)

    if not keep:
        keep = [{'name': s, 'subscribers': 0, 'over18': False, 'public_description': 'fallback'} for s in FALLBACK_SUBS]

    OUT_TXT.parent.mkdir(parents=True, exist_ok=True)
    OUT_TXT.write_text('\n'.join(x['name'] for x in keep) + ('\n' if keep else ''), encoding='utf-8')
    OUT_JSON.write_text(json.dumps({'queries': QUERIES, 'count': len(keep), 'subreddits': keep}, indent=2), encoding='utf-8')

    print(f'discovered_subs={len(keep)}')
    print('top=' + ','.join(x['name'] for x in keep[:20]))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
