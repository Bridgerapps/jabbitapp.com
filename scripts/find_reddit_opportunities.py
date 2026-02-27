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

def load_proxy():
    """Load Reddit proxy from env."""
    try:
        with open('/home/jabbit/.openclaw/workspace/scripts/proxy.env') as f:
            content = f.read()
            for line in content.split('\n'):
                if line.startswith('export REDDIT_PROXY_URL='):
                    return line.split('=')[1].strip().strip('"').strip("'")
                if line.startswith('export PROXY_HOST='):
                    # Build from components
                    host = line.split('=')[1].strip().strip('"')
                if line.startswith('export PROXY_USER='):
                    user = line.split('=')[1].strip().strip('"')
                if line.startswith('export PROXY_PASS='):
                    password = line.split('=')[1].strip().strip('"')
            # Try alternative: build from components
            import os
            lines = content.split('\n')
            vars = {}
            for line in lines:
                if '=' in line and not line.startswith('#'):
                    key, val = line.split('=', 1)
                    vars[key] = val.strip().strip('"').strip("'")
            if 'PROXY_HOST' in vars and 'PROXY_USER' in vars:
                return f"http://{vars.get('PROXY_USER')}:{vars.get('PROXY_PASS')}@{vars.get('PROXY_HOST')}:{vars.get('PROXY_PORT', '80')}"
    except Exception as e:
        print(f"Proxy load error: {e}", flush=True)
    return ''

def load_session():
    """Load Reddit session cookie."""
    try:
        with open('/home/jabbit/.openclaw/workspace/.reddit-session') as f:
            return f.read().strip()
    except:
        return ''

def fetch_posts(subreddit, proxy, cookie, limit=50):
    """Fetch recent posts from a subreddit."""
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
    cookie = load_session()
    
    if not cookie:
        print("ERROR: No Reddit session cookie found")
        return []
    
    all_posts = []
    
    # Fetch from all target subs
    for sub in TARGET_SUBS:
        print(f"Checking r/{sub}...", flush=True)
        posts = fetch_posts(sub, proxy, cookie)
        
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
