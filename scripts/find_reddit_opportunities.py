#!/usr/bin/env python3
"""
Reddit Opportunity Finder
Finds posts matching target patterns for commenting opportunities.
"""

import json
import random
import re
import subprocess
import time
import os
from datetime import datetime, UTC

# Target subreddits
TARGET_SUBS = ['Mounjaro', 'Ozempic', 'Zepbound', 'Semaglutide', 'Wegovy', 'GLP1', 'weightloss', 'biohackers', 'longevity']

# Opportunity keywords - what we're looking for
OPPORTUNITY_PATTERNS = {
    'app_recommendation': [
        'what app', 'what do you use', 'which app', 'app recommendations',
        'recommend an app', 'best app', 'favorite app', 'tracking app',
        'what do you use to track', 'logging app', 'tool for tracking'
    ],
    'shotsy_mention': [
        'shotsy', 'shotsy app', 'use shotsy', 'shothy', 'shothy app'
    ],
    'question': [
        '?', 'how do you', 'anyone know', 'is there an', 'looking for'
    ]
}

PROXY_ENV = "/home/jabbit/.openclaw/workspace/scripts/proxy.env"
VAR_RE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")


def _expand_vars(val: str, vars: dict[str, str]) -> str:
    return VAR_RE.sub(lambda m: vars.get(m.group(1), os.environ.get(m.group(1), m.group(0))), val)


def load_proxy() -> str:
    """Load Reddit proxy URL from proxy.env.

    Note: proxy.env may define REDDIT_PROXY_URL using ${VAR} placeholders.
    We parse + expand those placeholders so curl gets a real URL.
    """
    try:
        if not os.path.exists(PROXY_ENV):
            return ""

        vars: dict[str, str] = {}
        with open(PROXY_ENV, "r", encoding="utf-8") as f:
            for raw in f:
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                if line.startswith("export "):
                    line = line[len("export ") :]
                if "=" not in line:
                    continue
                k, v = line.split("=", 1)
                k = k.strip()
                v = v.strip().strip('"').strip("'")
                v = _expand_vars(v, vars)
                vars[k] = v

        proxy = (vars.get("REDDIT_PROXY_URL") or "").strip()
        # If it still contains ${...}, ignore and build from components.
        if proxy and ("${" not in proxy):
            return proxy

        host = (vars.get("PROXY_HOST") or "").strip()
        port = (vars.get("PROXY_PORT") or "80").strip()
        user = (vars.get("PROXY_USER") or "").strip()
        password = (vars.get("PROXY_PASS") or "").strip()

        if host and user:
            return f"http://{user}:{password}@{host}:{port}"

    except Exception as e:
        print(f"Proxy load error: {e}", flush=True)

    return ""

# Policy: discovery scripts must be public/no-cookie by default.

def fetch_posts(subreddit, proxy, limit=50):
    """Fetch recent posts from a subreddit (public-only)."""
    url = f'https://www.reddit.com/r/{subreddit}/new.json?limit={limit}'
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json',
    }
    
    cmd = ['curl', '-s', '--max-time', '30']
    if proxy:
        cmd.extend(['-x', proxy])
    for k, v in headers.items():
        cmd.extend(['-H', f'{k}: {v}'])
    cmd.extend([url])
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=35)
        if result.returncode != 0:
            return []
        data = json.loads(result.stdout)
        return (data.get('data', {}) or {}).get('children', [])
    except Exception as e:
        print(f"Error fetching r/{subreddit}: {e}", flush=True)
        return []

def score_post(post_data):
    """Score a post for opportunity priority."""
    title = (post_data.get('title') or '').lower()
    body = (post_data.get('selftext') or '').lower()
    text = f"{title} {body}"
    score = 0
    opportunity_type = None
    
    # Shotsy mentions - highest priority (competitor)
    if any(p in text for p in OPPORTUNITY_PATTERNS['shotsy_mention']):
        score += 100
        opportunity_type = 'shotsy'
    
    # App recommendations
    if any(p in text for p in OPPORTUNITY_PATTERNS['app_recommendation']):
        score += 50
        if not opportunity_type:
            opportunity_type = 'app_recommendation'
    
    # Questions
    if '?' in title:
        score += 10
        if not opportunity_type:
            opportunity_type = 'question'
    
    # Recency bonus
    created = post_data.get('created_utc', 0)
    age_hours = (time.time() - created) / 3600 if created else 999
    if age_hours < 6:
        score += 20
    elif age_hours < 12:
        score += 10
    elif age_hours < 24:
        score += 5
    
    # Engagement bonus
    comments = post_data.get('num_comments', 0)
    if 3 <= comments <= 50:
        score += 15
    elif comments > 50:
        score += 5
    
    return score, opportunity_type

def find_opportunities():
    """Main function to find Reddit opportunities."""
    proxy = load_proxy()
    
    all_posts = []
    
    # Fetch from all target subs
    for sub in TARGET_SUBS:
        print(f"Checking r/{sub}...", flush=True)
        posts = fetch_posts(sub, proxy)
        
        for p in posts:
            d = p.get('data', {})
            if not d:
                continue
                
            score, opp_type = score_post(d)
            if score > 0:
                d['_score'] = score
                d['_opportunity_type'] = opp_type
                all_posts.append(d)
    
    # Sort by score
    all_posts.sort(key=lambda x: x.get('_score', 0), reverse=True)
    
    return all_posts[:20]

if __name__ == '__main__':
    opportunities = find_opportunities()
    
    print(f"\n=== Found {len(opportunities)} opportunities ===\n", flush=True)
    
    for i, post in enumerate(opportunities, 1):
        title = post.get('title', '')[:80]
        sub = post.get('subreddit', '')
        score = post.get('_score', 0)
        opp_type = post.get('_opportunity_type', 'question')
        url = f"https://reddit.com{post.get('permalink', '')}"
        comments = post.get('num_comments', 0)
        
        print(f"{i}. r/{sub} | {opp_type} | score:{score} | {comments} comments")
        print(f"   {title}")
        print(f"   {url}")
        print()
