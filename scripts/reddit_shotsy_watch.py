#!/usr/bin/env python3
"""Watch Reddit for Shotsy mentions and produce opportunity metadata.
Uses public/no-cookie reads by default to avoid tying discovery to account identity.
"""

import datetime as dt
import json
import os
import re
import subprocess
from pathlib import Path

WS = Path('/home/jabbit/.openclaw/workspace')
OUT = WS / 'data' / 'reddit' / 'shotsy-opportunities.json'
LIMIT = int(os.getenv('SHOTSY_WATCH_LIMIT', '80'))
SUBS_MAX = int(os.getenv('SHOTSY_WATCH_SUBS_MAX', '999'))


def load_env(path: Path) -> dict:
    env = {}
    if not path.exists():
        return env
    for raw in path.read_text(encoding='utf-8', errors='ignore').splitlines():
        line = raw.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        if line.startswith('export '):
            line = line[len('export '):]
        k, v = line.split('=', 1)
        env[k.strip()] = v.strip().strip('"').strip("'")

    # Resolve simple ${VAR} placeholders (single pass is enough for this env file).
    for k, v in list(env.items()):
        for ref_k, ref_v in env.items():
            v = v.replace('${' + ref_k + '}', ref_v)
        env[k] = v

    return env


def resolve_proxy(proxy_env: dict) -> str:
    p = proxy_env.get('REDDIT_PROXY_URL', '')
    if p and '${' not in p:
        return p
    host = proxy_env.get('PROXY_HOST', '')
    port = proxy_env.get('PROXY_PORT', '80')
    user = proxy_env.get('PROXY_USER', '')
    pwd = proxy_env.get('PROXY_PASS', '')
    if host and user:
        return f'http://{user}:{pwd}@{host}:{port}'
    return ''


def curl_json(url: str, proxy: str = '', cookie: str = '') -> dict:
    ua = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'
    cmd = ['curl', '-sS', '--max-time', '30', '-A', ua, '-H', 'Accept: application/json']
    if proxy:
        cmd += ['-x', proxy]
    if cookie:
        cmd += ['-H', f'Cookie: reddit_session={cookie}']
    cmd += [url]
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0 or not p.stdout.strip():
        return {}
    try:
        return json.loads(p.stdout)
    except Exception:
        return {}


def main() -> int:
    (WS / 'data' / 'reddit').mkdir(parents=True, exist_ok=True)

    proxy_env = load_env(WS / 'scripts' / 'proxy.env')
    proxy = resolve_proxy(proxy_env)

    # Discovery should be public/no-cookie by default.
    search_url = (
        'https://www.reddit.com/search.json?'
        f'q=shotsy&sort=new&t=day&type=link&limit={LIMIT}&raw_json=1'
    )
    j = curl_json(search_url, proxy=proxy, cookie='')
    children = ((j.get('data') or {}).get('children') or [])

    now = dt.datetime.now(dt.timezone.utc)
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0).timestamp()

    posts = []
    sub_counts = {}
    for c in children:
        d = c.get('data') or {}
        title = (d.get('title') or '')
        body = (d.get('selftext') or '')
        text = f"{title} {body}".lower()
        if 'shotsy' not in text:
            continue
        created = float(d.get('created_utc') or 0)
        if created < day_start:
            continue

        sub = (d.get('subreddit') or '').strip()
        pid = (d.get('id') or '').strip()
        if not sub or not pid:
            continue

        sub_counts[sub] = sub_counts.get(sub, 0) + 1
        posts.append({
            'post_id': pid,
            'subreddit': sub,
            'title': title,
            'permalink': 'https://reddit.com' + (d.get('permalink') or ''),
            'created_utc': created,
            'num_comments': d.get('num_comments', 0),
        })

    # Prioritize subs with more same-day mentions; keep all by default.
    ranked_subs = sorted(sub_counts.keys(), key=lambda s: sub_counts[s], reverse=True)
    if SUBS_MAX > 0:
        ranked_subs = ranked_subs[:SUBS_MAX]

    payload = {
        'generated_at': int(now.timestamp()),
        'mentions_today': len(posts),
        'tracked_subreddits': ranked_subs,
        'sub_counts': sub_counts,
        'posts': posts[:120],
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')

    print(f"shotsy_mentions_today={payload['mentions_today']} tracked_subs={len(ranked_subs)}")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
