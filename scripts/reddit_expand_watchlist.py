#!/usr/bin/env python3
"""Expand subreddit watchlist for peptide/cosmetic communities and save to file."""

from __future__ import annotations

import json
import importlib.util
from pathlib import Path

WS = Path('/home/jabbit/.openclaw/workspace')
OUT_TXT = WS / 'data' / 'reddit' / 'community-watch-subreddits.txt'
OUT_JSON = WS / 'data' / 'reddit' / 'community-watch-subreddits.json'

KEYWORDS = [
    'peptide',
    'peptides',
    'tirzepatide',
    'semaglutide',
    'retatrutide',
    'mounjaro',
    'zepbound',
    'ozempic',
    'wegovy',
    'glp1',
    'cosmetic peptides',
    'fat loss',
    'weight loss meds',
]

EXCLUDE_PREFIXES = ('u_',)
EXCLUDE_EXACT = {'Pizza'}


def main() -> int:
    mod_path = WS / 'scripts' / 'reddit_shotsy_watch.py'
    spec = importlib.util.spec_from_file_location('shotsy', str(mod_path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)  # type: ignore

    proxy = mod.resolve_proxy(mod.load_env(WS / 'scripts' / 'proxy.env'))

    counts = {}
    by_keyword = {}

    for q in KEYWORDS:
        url = f'https://www.reddit.com/subreddits/search.json?q={q}&limit=100&include_over_18=off&raw_json=1'
        j = mod.curl_json(url, proxy=proxy, cookie='')
        children = ((j.get('data') or {}).get('children') or [])

        found = {}
        for c in children:
            d = c.get('data') or {}
            name = (d.get('display_name') or '').strip()
            if not name:
                continue
            if name.startswith(EXCLUDE_PREFIXES):
                continue
            if name in EXCLUDE_EXACT:
                continue
            found[name] = found.get(name, 0) + 1
            counts[name] = counts.get(name, 0) + 1

        by_keyword[q] = found

    ranked = [k for k, _ in sorted(counts.items(), key=lambda kv: kv[1], reverse=True)]

    OUT_TXT.parent.mkdir(parents=True, exist_ok=True)
    OUT_TXT.write_text('\n'.join(ranked) + ('\n' if ranked else ''), encoding='utf-8')
    OUT_JSON.write_text(json.dumps({
        'keywords': KEYWORDS,
        'counts_total': counts,
        'counts_by_keyword': by_keyword,
        'subreddits': ranked,
    }, indent=2), encoding='utf-8')

    print(f'community_watchlist_subs={len(ranked)}')
    if ranked:
        print('top=' + ','.join(ranked[:30]))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
