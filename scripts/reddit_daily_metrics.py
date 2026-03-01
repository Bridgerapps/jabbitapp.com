#!/usr/bin/env python3
"""Emit compact Reddit daily metrics summary for operator updates.
Output format:
  total_karma=<n> new_karma_today=<n> jabbit_mentions_today=<n>
"""

import datetime as dt
import json
import os
import subprocess
from pathlib import Path

WS = Path('/home/jabbit/.openclaw/workspace')
BASELINE_DIR = WS / 'data' / 'reddit' / 'daily-baseline'
SHOTSY_FILE = WS / 'data' / 'reddit' / 'shotsy-opportunities.json'


def load_env(path: Path) -> dict:
    env = {}
    if not path.exists():
        return env
    for raw in path.read_text(encoding='utf-8', errors='ignore').splitlines():
        line = raw.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        k, v = line.split('=', 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def curl_json(url: str, proxy: str = '', cookie: str = ''):
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
    proxy_env = load_env(WS / 'scripts' / 'proxy.env')
    reddit_env = load_env(WS / 'scripts' / 'reddit.env')

    proxy = proxy_env.get('REDDIT_PROXY_URL', '')
    if (not proxy) or ('${' in proxy):
        host = proxy_env.get('PROXY_HOST', '')
        port = proxy_env.get('PROXY_PORT', '80')
        user = proxy_env.get('PROXY_USER', '')
        pwd = proxy_env.get('PROXY_PASS', '')
        if host and user:
            proxy = f'http://{user}:{pwd}@{host}:{port}'

    cookie = ''
    cookie_path = WS / '.reddit-session'
    if cookie_path.exists():
        cookie = cookie_path.read_text(encoding='utf-8', errors='ignore').strip()

    username = reddit_env.get('REDDIT_USERNAME', 'LifespanMaxer')

    me = curl_json('https://www.reddit.com/api/me.json?raw_json=1', proxy=proxy, cookie=cookie)
    total_karma = ((me.get('data') or {}).get('total_karma'))
    if total_karma is None:
        # Fallback to 0 if auth failed; keep output shape stable.
        total_karma = 0

    now = dt.datetime.now(dt.timezone.utc)
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0).timestamp()

    comments = curl_json(f'https://www.reddit.com/user/{username}/comments.json?limit=200&raw_json=1', proxy=proxy, cookie=cookie)
    children = ((comments.get('data') or {}).get('children') or [])

    mentions_today = 0
    for c in children:
        d = c.get('data') or {}
        created = float(d.get('created_utc') or 0)
        if created < day_start:
            continue
        body = (d.get('body') or '').lower()
        if 'jabbit' in body:
            mentions_today += 1

    BASELINE_DIR.mkdir(parents=True, exist_ok=True)
    day_key = now.strftime('%Y-%m-%d')
    baseline_file = BASELINE_DIR / f'{day_key}.txt'

    if baseline_file.exists():
        try:
            baseline = int(baseline_file.read_text().strip())
        except Exception:
            baseline = int(total_karma)
    else:
        baseline = int(total_karma)
        baseline_file.write_text(str(baseline), encoding='utf-8')

    day_gain = int(total_karma) - int(baseline)

    competitor_mentions_today = 0
    try:
        sj = json.loads(SHOTSY_FILE.read_text(encoding='utf-8'))
        competitor_mentions_today = int(sj.get('mentions_today') or 0)
    except Exception:
        competitor_mentions_today = 0

    print(
        f'total_karma={int(total_karma)} '
        f'new_karma_today={day_gain} '
        f'jabbit_mentions_today={mentions_today} '
        f'competitor_mentions_today={competitor_mentions_today}'
    )
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
