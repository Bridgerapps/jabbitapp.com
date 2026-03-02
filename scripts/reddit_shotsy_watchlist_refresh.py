#!/usr/bin/env python3
"""Refresh full subreddit watchlist where 'Shotsy' is mentioned in last 90 days.

Uses Reddit search (t=year), paginates result pages, then filters posts by created_utc >= now-90d.
Writes:
- data/reddit/shotsy-watch-subreddits.txt
- data/reddit/shotsy-watch-subreddits.json
"""

from __future__ import annotations

import json
import time
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

    cutoff = time.time() - (90 * 24 * 3600)
    counts = {}
    kept_posts = 0
    scanned_posts = 0

    # Reddit search does not support 90d directly; use year window + pagination then filter by age.
    after = None
    pages = 0
    max_pages = 12
    while pages < max_pages:
        base = 'https://www.reddit.com/search.json?q=shotsy&sort=new&t=year&type=link&limit=100&raw_json=1'
        url = base + (f'&after={after}' if after else '')
        j = mod.curl_json(url, proxy=proxy, cookie='')
        data = j.get('data') or {}
        children = data.get('children') or []
        if not children:
            break

        for c in children:
            d = c.get('data') or {}
            scanned_posts += 1
            created = float(d.get('created_utc') or 0)
            if created and created < cutoff:
                continue

            text = f"{d.get('title','')} {d.get('selftext','')}".lower()
            if 'shotsy' not in text:
                continue

            sub = (d.get('subreddit') or '').strip()
            if not sub or sub.lower().startswith('u_'):
                continue

            counts[sub] = counts.get(sub, 0) + 1
            kept_posts += 1

        after = data.get('after')
        pages += 1
        if not after:
            break

    ranked = [k for k, _ in sorted(counts.items(), key=lambda kv: kv[1], reverse=True)]

    OUT_TXT.parent.mkdir(parents=True, exist_ok=True)
    OUT_TXT.write_text('\n'.join(ranked) + ('\n' if ranked else ''), encoding='utf-8')
    OUT_JSON.write_text(json.dumps({
        'window_days': 90,
        'method': 'reddit_search_year_plus_created_utc_filter',
        'scanned_posts': scanned_posts,
        'kept_posts': kept_posts,
        'counts_total': counts,
        'subreddits': ranked,
    }, indent=2), encoding='utf-8')

    print(f"shotsy_watchlist_subs={len(ranked)}")
    if ranked:
        print('subs=' + ','.join(ranked))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
