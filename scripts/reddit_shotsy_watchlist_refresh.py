#!/usr/bin/env python3
"""Refresh full subreddit watchlist where 'Shotsy' is mentioned.

Looks across multiple Reddit search windows (day/week/month/year) and writes:
- data/reddit/shotsy-watch-subreddits.txt
- data/reddit/shotsy-watch-subreddits.json
"""

from __future__ import annotations

import json
from pathlib import Path
import importlib.util

WS = Path('/home/jabbit/.openclaw/workspace')
OUT_TXT = WS / 'data' / 'reddit' / 'shotsy-watch-subreddits.txt'
OUT_JSON = WS / 'data' / 'reddit' / 'shotsy-watch-subreddits.json'


def main() -> int:
    mod_path = WS / 'scripts' / 'reddit_shotsy_watch.py'
    spec = importlib.util.spec_from_file_location('shotsy', str(mod_path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)  # type: ignore

    proxy = mod.resolve_proxy(mod.load_env(WS / 'scripts' / 'proxy.env'))

    windows = ['day', 'week', 'month', 'year']
    counts = {}
    by_window = {}

    for t in windows:
        url = f'https://www.reddit.com/search.json?q=shotsy&sort=new&t={t}&type=link&limit=100&raw_json=1'
        j = mod.curl_json(url, proxy=proxy, cookie='')
        children = ((j.get('data') or {}).get('children') or [])

        sub_counts = {}
        for c in children:
            d = c.get('data') or {}
            text = f"{d.get('title','')} {d.get('selftext','')}".lower()
            if 'shotsy' not in text:
                continue
            sub = (d.get('subreddit') or '').strip()
            # Keep only proper subreddit names.
            if not sub or sub.lower().startswith('u_'):
                continue
            sub_counts[sub] = sub_counts.get(sub, 0) + 1
            counts[sub] = counts.get(sub, 0) + 1

        by_window[t] = sub_counts

    ranked = [k for k, _ in sorted(counts.items(), key=lambda kv: kv[1], reverse=True)]

    OUT_TXT.parent.mkdir(parents=True, exist_ok=True)
    OUT_TXT.write_text('\n'.join(ranked) + ('\n' if ranked else ''), encoding='utf-8')
    OUT_JSON.write_text(json.dumps({
        'windows': windows,
        'counts_total': counts,
        'counts_by_window': by_window,
        'subreddits': ranked,
    }, indent=2), encoding='utf-8')

    print(f"shotsy_watchlist_subs={len(ranked)}")
    if ranked:
        print('subs=' + ','.join(ranked))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
