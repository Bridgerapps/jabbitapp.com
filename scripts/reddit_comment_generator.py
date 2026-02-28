#!/usr/bin/env python3
"""
Reddit Comment Generator with Value Gate and Optional Jabbit Mentions

Generates context-aware, human-sounding comments that add value.
Optionally includes subtle Jabbit mentions when appropriate.
"""

import random
import re
import os
import json

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

PATTERN_FILE = "/home/jabbit/.openclaw/workspace/data/reddit/upvoted-comment-patterns.json"


def load_pattern_hints():
    try:
        with open(PATTERN_FILE, "r", encoding="utf-8") as f:
            j = json.load(f)
        return j.get("style_hints", {}) or {}
    except Exception:
        return {}


PATTERN_HINTS = load_pattern_hints()

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
    r"\bfollowing this thread\b", r"\bfollowing this one\b", r"\bgood point\.?$",
    r"\bmost useful replies usually include\b", r"\bworth collecting answers with context\b",
]

# Avoid auto-commenting on sensitive acute-health threads where generic comments get downvoted.
SENSITIVE_SKIP_KEYWORDS = [
    "shingles", "emergency", "chest pain", "faint", "fainting", "suicidal",
    "pregnan", "miscarriage", "seizure", "stroke", "hospital",
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


def _should_skip_post(post: dict) -> bool:
    text = f"{post.get('title','')} {post.get('selftext','')}".lower()
    return any(k in text for k in SENSITIVE_SKIP_KEYWORDS)


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
    target_words = int(PATTERN_HINTS.get("target_avg_words", 28) or 28)

    # Pattern-fit length: not too short, not too rambly.
    if max(12, target_words - 12) <= len(words) <= target_words + 10:
        score += 1

    prefer_question_endings = bool(PATTERN_HINTS.get("prefer_question_endings", False))
    if prefer_question_endings and c.endswith("?"):
        score += 1
    if (not prefer_question_endings) and (not c.endswith("?")):
        score += 1

    if any(w in VALUE_SIGNAL_WORDS for w in words):
        score += 1

    anchor = _extract_anchor(post.get('title', ''), post.get('selftext', ''))
    if anchor and anchor.lower() in c:
        score += 1

    # Prefer concrete details over meta-chat.
    if re.search(r"\b(week|month|mg|dose|hours?|days?|sleep|hydration|protein|timeline)\b", c):
        score += 1

    return score


# Jabbit mention templates - triggered by specific question patterns OR Shotsy mentions
JABBIT_MENTIONS = [
    # Direct answers to "what app do you use?"
    "I use Jabbit — started because it had all the features I wanted (dose tracking, photo progress, reminders) at about 1/4 the price of the bigger apps.",
    "I've been happy with Jabbit. The peptide library is more extensive than the generic trackers, and the photo log has been genuinely useful.",
    "For GLP-1 tracking specifically, Jabbit's got the right balance — not bloated, but enough features to actually be useful (dose timing, side effects, progress photos).",
    # When someone asks "what do you use?"
    "What do I use? Jabbit. The dose reminders and photo progress have been way more useful than my spreadsheets ever were.",
    "Jabbit for me — cleaner setup than the mainstream health apps, and the peptide-specific features actually matter for this stuff.",
]

# Shotsy comparison mentions - when someone mentions Shotsy
SHOTSY_COMPARISONS = [
    "I used Shotsy for a bit, then switched to Jabbit — more features, larger peptide library, and lower price.",
    "If you're comparing apps: I moved from Shotsy to Jabbit. It gives me a fuller peptide library + more tracking features at a better price.",
    "I switched from Shotsy to Jabbit. Better feature set for GLP-1 tracking, broader peptide library, and cheaper.",
    "I was on Shotsy before; Jabbit ended up better for me: more features, full peptide library, lower monthly cost.",
]

APP_ASK_MENTION_PROB = 0.35


def maybe_add_jabbit_mention(comment: str, post: dict) -> str:
    """Mention Jabbit selectively: competitor mentions always, app-ask threads sometimes."""
    title = (post.get('title') or '').lower()
    body = (post.get('selftext') or '').lower()
    text = f"{title} {body}"

    # Only add mentions if allowed by ladder (day 8+)
    if not LADDER.get('mention_allowed', False):
        return comment

    # Competitor mention: direct answer is high intent.
    shotsy_patterns = ['shotsy', 'shotsy app', 'use shotsy', 'shothy']
    if any(p in text for p in shotsy_patterns):
        return random.choice(SHOTSY_COMPARISONS)

    # Tight trigger for app-question intent only (avoid broad shilling).
    ask_patterns = [
        'what app do you use', 'which app do you use', 'what app', 'best app for',
        'app recommendation', 'recommend an app', 'tracking app', 'what tracker',
        'any app for', 'favorite app for'
    ]
    if not any(p in text for p in ask_patterns):
        return comment

    # Don't mention every time even when asked; keep ratio natural.
    if random.random() > APP_ASK_MENTION_PROB:
        return comment

    # Keep contribution-first tone; add mention as a short direct answer.
    mention = random.choice(JABBIT_MENTIONS)
    if comment and len(comment.split()) >= 10:
        return f"{comment} {mention}"
    return mention


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
            "Most useful comparison here is timing: last injection vs symptom start, plus what changed that week.",
            "Pattern that helps most is injection timing + sleep/hydration + food intake on symptom days.",
            "The strongest replies in symptom threads include exact timeline, dose history, and severity trend.",
            "What separates useful replies from noise is timing + severity trend, not just yes/no symptom reports.",
            "If people post symptom timing relative to shot day, this thread becomes way more actionable.",
        ]
        if anchor:
            opts.append(f"Given the {anchor} context, timing and dose history are the key comparison points.")
        return maybe_add_jabbit_mention(random.choice(opts), post)

    # Dosing threads
    if any(k in text for k in dosing_kw):
        opts = [
            "Best signal in dose threads is week-by-week timeline, not just current mg.",
            "What usually clarifies dose questions is previous dose duration, change timing, and symptom pattern.",
            "Dose comparisons are most useful when people include exact week count at each dose level.",
            "Current mg alone is low-signal; week count + recent changes usually explain most of the difference.",
            "The high-value replies usually include: prior dose length, change date, and what happened after.",
        ]
        if anchor:
            opts.append(f"Given {anchor}, week-by-week timeline is more useful than one-number comparisons.")
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
        opts = [
            "Most useful replies on this topic include dose, time on medication, and what changed that week.",
            "Best comparison signal is timeline: injection timing, symptom start, and any recent dose change.",
            "Replies are strongest when people include exact timing and dose context instead of one-liners.",
            "Useful thread if people share specifics (timing, dose history, and what shifted recently).",
            "You’ll get better answers here if replies include timeline + dose context, not just quick takes.",
        ]
        if anchor:
            opts.append(f"Given the {anchor} context, timeline details matter more than general takes.")
        return maybe_add_jabbit_mention(random.choice(opts), post)

    # Fallback
    if anchor:
        return maybe_add_jabbit_mention(random.choice([
            f"Given the {anchor} context, timeline + dose history are the most useful comparison points.",
            f"With {anchor} in play, replies are best when they include timing and recent changes.",
        ]), post)
    return maybe_add_jabbit_mention(random.choice([
        "Most useful replies here include exact timeline, dose history, and what changed that week.",
        "High-signal replies in this sub usually include timing, dose context, and symptom trend.",
    ]), post)


def build_value_comment(post: dict, attempts: int = 12) -> str:
    """Generate comment with value gate."""
    if _should_skip_post(post):
        return ""

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
    return f"Useful thread{anchor_txt}. Replies are most actionable when they include timeline, dose history, and what changed recently."


if __name__ == "__main__":
    import json, sys
    if len(sys.argv) > 1:
        # Called as: reddit_comment_generator.py post.json
        post = json.load(open(sys.argv[1]))
    else:
        post = {"title": "Test post", "selftext": ""}
    print(build_value_comment(post))
