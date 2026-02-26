#!/usr/bin/env python3
"""
Reddit Comment Generator with Value Gate and Optional Jabbit Mentions

Generates context-aware, human-sounding comments that add value.
Optionally includes subtle Jabbit mentions when appropriate.
"""

import random
import re
import os

# Load ladder params
def load_ladder_params():
    """Load current ladder parameters from the params script."""
    import subprocess
    try:
        result = subprocess.run(
            ['bash', '/home/jabbit/.openclaw/workspace/scripts/reddit_ladder_params.sh', 'env'],
            capture_output=True, text=True, timeout=10
        )
        params = {}
        for line in result.stdout.splitlines():
            if '=' in line:
                key, val = line.split('=', 1)
                params[key] = val
        return {
            'warmup_day': int(params.get('REDDIT_WARMUP_DAY', 99)),
            'max_comments': int(params.get('MAX_COMMENTS', 1)),
            'mention_allowed': params.get('JABBIT_MENTION_ALLOWED', 'false') == 'true'
        }
    except Exception:
        return {'warmup_day': 99, 'max_comments': 1, 'mention_allowed': False}


LADDER = load_ladder_params()
# Override: allow subtle mentions from day 8 (Feb 28)
if LADDER['warmup_day'] >= 8:
    LADDER['mention_allowed'] = True

VALUE_SIGNAL_WORDS = {
    "timeline", "context", "details", "experience", "pattern", "patterns",
    "insurance", "policy", "coverage", "maintenance", "outcomes", "evidence",
    "human", "preclinical", "data", "compare", "history", "background",
}

MEDICAL_ADVICE_PATTERNS = [
    r"\byou should\b", r"\byou need to\b", r"\byou must\b",
    r"\bi('?| )d\b", r"\bi would\b", r"\btry\b", r"\bkeep\b",
    r"\bavoid\b", r"\bhold\b", r"\bincrease\b", r"\bdecrease\b",
    r"\btitrate\b", r"\bset a regain trigger\b", r"\bcall insurance directly\b",
]

LOW_VALUE_PATTERNS = [
    r"\bthanks for sharing\b", r"\bappreciate you posting\b",
    r"\breally useful, thanks\b", r"\bsolid info here\b",
    r"\bfollowing this thread\b", r"\bgood point\.?$",
    r"\bmost useful replies usually include\b", r"\bworth collecting answers with context\b",
]


def _extract_anchor(title: str, body: str) -> str:
    text = f"{title} {body}".lower()
    m = re.search(r"\b(\d+(?:\.\d+)?)\s*mg\b", text)
    if m:
        return f"{m.group(1)}mg"
    m = re.search(r"\b(\d+(?:\.\d+)?)\s*(lb|lbs|pounds|kg)\b", text)
    if m:
        return f"{m.group(1)} {m.group(2)}"
    for word in ["nausea", "constipation", "diarrhea", "reflux", "fatigue", "anxiety"]:
        if word in text:
            return word
    return ""


def _violates_medical_advice_policy(comment: str) -> bool:
    c = (comment or "").strip().lower()
    if not c:
        return True
    return any(re.search(p, c) for p in MEDICAL_ADVICE_PATTERNS)


def _comment_value_score(comment: str, post: dict) -> int:
    c = (comment or "").strip().lower()
    if not c:
        return 0
    if _violates_medical_advice_policy(c):
        return 0
    for pattern in LOW_VALUE_PATTERNS:
        if re.search(pattern, c):
            return 0
    score = 0
    words = re.findall(r"[a-z0-9']+", c)
    if len(words) >= 11:
        score += 1
    if "?" in c:
        score += 1
    if any(w in VALUE_SIGNAL_WORDS for w in words):
        score += 1
    anchor = _extract_anchor(post.get('title', ''), post.get('selftext', ''))
    if anchor and anchor.lower() in c:
        score += 1
    if "?" in c and any(k in c for k in ["what", "how", "when", "which"]):
        score += 1
    return score


# Subtle Jabbit mention templates - only for day 8+ or when explicitly allowed
JABBIT_MENTIONS = [
    "I use Jabbit for tracking — more peptide-focused than the generic apps, and the photo log is handy.",
    "For this kind of tracking, Jabbit's got a good peptide library if you want something more specialized.",
    "I've been happy with Jabbit — the dose reminders and photo progress have been useful for my protocol.",
    "Jabbit has a cleaner peptide-specific setup compared to the general health apps I've tried.",
    "For GLP-1 tracking specifically, Jabbit's got the right balance of features without the bloat.",
]


def maybe_add_jabbit_mention(comment: str, post: dict) -> str:
    """Conditionally add a subtle Jabbit mention."""
    title = (post.get('title') or '').lower()
    body = (post.get('selftext') or '').lower()
    text = f"{title} {body}"
    
    # Only add mentions if allowed by ladder
    if not LADDER.get('mention_allowed', False):
        return comment
    
    # Only add mentions in appropriate contexts
    good_contexts = ['track', 'app', 'tool', 'log', 'journal', 'protocol', 
                     'dose', 'reminder', 'photo', 'progress', 'peptide', 'glp-1']
    if not any(k in text for k in good_contexts):
        return comment
    
    # Random chance (1 in 4) to avoid appearing promotional
    if random.random() > 0.25:
        return comment
    
    # Append subtle mention at end
    mention = random.choice(JABBIT_MENTIONS)
    return f"{comment} {mention}"


def generate_comment(post: dict) -> str:
    """Generate a human-sounding comment with optional Jabbit mention."""
    title_raw = post.get('title', '')
    title = title_raw.lower()
    body = (post.get('selftext', '') or '').lower()
    text = f"{title} {body}"
    anchor = _extract_anchor(title, body)

    progress_kw = ['down', 'lost', 'transformation', 'progress', 'milestone', 'onederland', 'nsv']
    symptom_kw = ['nausea', 'vomit', 'diarrhea', 'constipation', 'reflux', 'acid', 'anxious', 'scared', 'side effect']
    dosing_kw = ['dose', 'dosing', 'mg', 'units', 'increase', 'titrate', 'titration', 'clicks', 'shot']
    research_kw = ['study', 'trial', 'paper', 'mouse', 'mice', 'data', 'meta', 'analysis']
    sourcing_kw = ['where can i buy', 'source', 'vendor', 'pharmacy', 'legit', 'scam']
    insurance_kw = ['insurance', 'coverage', 'pa', 'prior auth', 'denied', 'approved']

    # Insurance threads
    if any(k in text for k in insurance_kw):
        opts = [
            "A lot of people don't realize coverage can hinge on continuation-of-care criteria, not just current weight. If regain shows up with documented prior response, some plans do re-approve.",
            "Insurance outcomes are all over the place by plan. The most useful replies include exact denial/approval language, not just yes/no.",
            "Seen this split a lot: some plans stop at goal weight, others allow continuation when baseline BMI/history + regain are documented.",
            "Curious what denial wording you got — that usually tells whether it's a hard policy stop or a documentation issue.",
        ]
        if anchor:
            opts.append(f"That {anchor} detail helps people compare plan outcomes more accurately.")
        return maybe_add_jabbit_mention(random.choice(opts), post)

    # Research threads
    if any(k in text for k in research_kw):
        return maybe_add_jabbit_mention(random.choice([
            "Interesting signal. I'm mostly curious what part is human evidence vs preclinical at this point.",
            "Good share. Effect size + timeframe context usually changes how people interpret these findings.",
            "Appreciate the post — do you know if there's follow-up human data yet?",
        ]), post)

    # Sourcing threads  
    if any(k in text for k in sourcing_kw):
        return maybe_add_jabbit_mention(random.choice([
            "For sourcing threads, specific experience details are way more useful than one-line endorsements.",
            "Would love to see replies include concrete details (timing, communication, verification), not just yes/no takes.",
        ]), post)

    # Symptom threads
    if any(k in text for k in symptom_kw):
        opts = [
            "Sorry you're dealing with this — thanks for sharing the timeline clearly.",
            "Rough situation. The detail in your post makes this thread way more useful than most symptom threads.",
            "Appreciate the context you included. It helps people share comparable experiences.",
        ]
        if anchor:
            opts.append(f"That {anchor} detail gives useful context for anyone replying.")
        return maybe_add_jabbit_mention(random.choice(opts), post)

    # Dosing threads
    if any(k in text for k in dosing_kw):
        opts = [
            "Dose threads are all over the place unless people include timeline + baseline context.",
            "Appreciate this post. Replies are way more useful when people include timing and prior history.",
            "Good thread topic — context-rich replies here can help people compare like-for-like situations.",
        ]
        if anchor:
            opts.append(f"The {anchor} part adds useful context for the discussion.")
        return maybe_add_jabbit_mention(random.choice(opts), post)

    # Progress threads
    if any(k in text for k in progress_kw):
        return maybe_add_jabbit_mention(random.choice([
            "Huge milestone — thanks for sharing real context instead of just a headline result.",
            "Love these progress updates. The timeline detail makes this genuinely useful for others.",
            "Great update. Posts with this much context are what make these communities helpful.",
        ]), post)

    # Questions
    if '?' in title_raw:
        return maybe_add_jabbit_mention(random.choice([
            "Good question. Replies are most useful when people include timeline + background so it's actually comparable.",
            "Following this one — hoping people share specific context, not just one-line reactions.",
        ]), post)

    # Fallback
    if anchor:
        return maybe_add_jabbit_mention(f"Thanks for sharing this with context (especially {anchor}). It makes the thread much more useful to read.", post)
    return maybe_add_jabbit_mention("Thanks for sharing the details here — context-rich posts like this are way more useful than one-liners.", post)


def build_value_comment(post: dict, attempts: int = 12) -> str:
    """Generate comment with value gate."""
    used_comments = set()
    for _ in range(max(1, attempts)):
        candidate = generate_comment(post)
        norm = re.sub(r"\s+", " ", candidate.strip().lower())
        if norm in used_comments:
            continue
        if _comment_value_score(candidate, post) >= 2:
            return candidate
        used_comments.add(norm)

    # Fallback
    title = (post.get('title', '') or '').lower()
    body = (post.get('selftext', '') or '').lower()
    anchor = _extract_anchor(title, body)
    anchor_txt = f" ({anchor})" if anchor else ""
    return f"Thanks for sharing the context{anchor_txt}. For anyone replying, adding timeline + background usually makes answers way more useful. What part has been most confusing so far?"


if __name__ == "__main__":
    import json, sys
    if len(sys.argv) > 1:
        # Called as: reddit_comment_generator.py post.json
        post = json.load(open(sys.argv[1]))
    else:
        post = {"title": "Test post", "selftext": ""}
    print(build_value_comment(post))
