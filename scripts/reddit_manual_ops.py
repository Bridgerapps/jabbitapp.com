#!/usr/bin/env python3
"""Manual-only Reddit distribution ops.

This module exists to make the Reddit workflow *drivable* without lying:
- discovery/drafting can be automated (no auth)
- reading the live thread, posting, and any authenticated actions are MANUAL ONLY
- logging is explicit and tied to a same-run candidate pack with freshness windows

Operator flow (happy path):
  1) discover -> produces a fresh run file (expires soon)
  2) prepare -> choose exactly one candidate; prints checklist + writes active_candidate.json
  3) operator posts manually in browser/app
  4) log -> records verified outcome (comment URL or abort), tied to active_candidate

No authenticated requests are performed by this script.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import textwrap
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

WS = Path("/home/jabbit/.openclaw/workspace")
DATA = WS / "data" / "reddit"
RUNS_DIR = DATA / "runs"
ACTIVE = DATA / "active_candidate.json"
LEDGER = DATA / "manual-actions-ledger.jsonl"
FINDER = WS / "scripts" / "find_reddit_opportunities_newacct.py"

DEFAULT_EXPIRES_MIN = int(os.getenv("REDDIT_CANDIDATE_EXPIRES_MIN", "360"))  # 6h
DEFAULT_LIMIT = int(os.getenv("REDDIT_DISCOVER_LIMIT", "8"))

COMMENT_URL_RE = re.compile(r"^https?://(www\.)?reddit\.com/r/[^/]+/comments/[a-z0-9]+/.+/[a-z0-9]+/?", re.I)
THREAD_URL_RE = re.compile(r"^https?://(www\.)?reddit\.com/r/[^/]+/comments/[a-z0-9]+/", re.I)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _run(cmd: list[str], timeout: int = 120) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def _json_dump(obj: Any, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _json_load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _human_ts(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _make_run_id(now: datetime) -> str:
    # stable-ish + readable; no need for uuid dependency.
    suffix = os.urandom(3).hex()
    return f"reddit-{now.strftime('%Y%m%dT%H%M%SZ')}-{suffix}"


@dataclass
class Candidate:
    post_id: str
    title: str
    body: str
    subreddit: str
    permalink: str
    num_comments: int
    age_hours: float
    proposed_comment: str


def discover(limit: int, expires_min: int) -> dict[str, Any]:
    now = utcnow()
    run_id = _make_run_id(now)
    expires_at = now + timedelta(minutes=expires_min)

    p = _run(["python3", str(FINDER)], timeout=180)
    if p.returncode != 0:
        raise RuntimeError((p.stderr or p.stdout or "finder failed").strip())

    cands: list[Candidate] = []
    for raw in (p.stdout or "").splitlines():
        if len(cands) >= limit:
            break
        parts = raw.split("|")
        if len(parts) < 7:
            continue
        post_id, title, body, sub, permalink, num_comments, age_hours = parts[:7]
        post_id = post_id.strip()
        if not post_id:
            continue
        # draft comment (no auth; local-only)
        env = {**os.environ, "POST_TITLE": title, "POST_BODY": body}
        code = (
            "import os,sys;"
            "sys.path.insert(0,'/home/jabbit/.openclaw/workspace/scripts');"
            "from reddit_comment_generator import build_value_comment;"
            "post={'title':os.environ.get('POST_TITLE',''),'selftext':os.environ.get('POST_BODY','')};"
            "print((build_value_comment(post) or '').strip())"
        )
        d = subprocess.run(["python3", "-c", code], capture_output=True, text=True, env=env, timeout=45)
        comment = (d.stdout or "").strip()
        if not comment:
            continue
        try:
            nc = int(float(num_comments or 0))
        except Exception:
            nc = 0
        try:
            ah = float(age_hours or 0)
        except Exception:
            ah = 0.0

        cands.append(
            Candidate(
                post_id=post_id,
                title=title.strip(),
                body=body.strip(),
                subreddit=sub.strip(),
                permalink=("https://reddit.com" + permalink.strip()) if permalink.strip().startswith("/") else permalink.strip(),
                num_comments=nc,
                age_hours=ah,
                proposed_comment=comment,
            )
        )

    run = {
        "run_id": run_id,
        "generated_at_utc": _human_ts(now),
        "expires_at_utc": _human_ts(expires_at),
        "policy": {
            "auth": "manual-only",
            "max_posts_per_prepare": 1,
            "notes": "Discovery/drafting are automated; reading + posting + verification are manual.",
        },
        "finder": str(FINDER),
        "count": len(cands),
        "candidates": [asdict(c) for c in cands],
    }
    out = RUNS_DIR / f"{run_id}.json"
    _json_dump(run, out)
    return {"path": str(out), "run": run}


def _require_fresh(run: dict[str, Any]):
    exp = datetime.fromisoformat(run["expires_at_utc"].replace("Z", "+00:00"))
    if utcnow() > exp:
        raise SystemExit(f"stale_run: expired_at={run['expires_at_utc']} (re-run discover)")


def prepare(run_path: Path, post_id: str) -> dict[str, Any]:
    run = _json_load(run_path)
    _require_fresh(run)

    cand = None
    for c in run.get("candidates", []):
        if c.get("post_id") == post_id:
            cand = c
            break
    if not cand:
        raise SystemExit(f"candidate_not_found: post_id={post_id} run={run.get('run_id')}")

    active = {
        "run_id": run["run_id"],
        "run_path": str(run_path),
        "selected_at_utc": _human_ts(utcnow()),
        "expires_at_utc": run["expires_at_utc"],
        "post_id": cand["post_id"],
        "subreddit": cand.get("subreddit"),
        "thread_url": cand.get("permalink"),
        "draft_comment": cand.get("proposed_comment"),
        "operator_intent": {
            "read_thread_live": True,
            "post_max_one": True,
            "no_cookie_automation": True,
        },
    }
    _json_dump(active, ACTIVE)
    return active


def _validate_comment_url(url: str) -> bool:
    return bool(COMMENT_URL_RE.match(url.strip()))


def _best_effort_verify_url(url: str) -> tuple[bool, str]:
    """Unauthenticated verification: just confirm the URL resolves (HTTP 200/3xx).

    This is not perfect, but it prevents totally fake logging.
    """
    url = url.strip()
    if not url:
        return False, "missing_url"
    try:
        p = subprocess.run(["curl", "-sS", "-I", "--max-time", "20", url], capture_output=True, text=True)
        if p.returncode != 0:
            return False, "curl_failed"
        head = (p.stdout or "")
        m = re.search(r"HTTP/\d\.\d\s+(\d+)", head)
        code = int(m.group(1)) if m else 0
        if 200 <= code < 400:
            return True, f"http={code}"
        return False, f"http={code}"
    except Exception as e:
        return False, f"exception:{e.__class__.__name__}"


def log_action(status: str, comment_url: str | None, final_text: str | None, note: str | None) -> dict[str, Any]:
    if not ACTIVE.exists():
        raise SystemExit("no_active_candidate: run prepare first")
    active = _json_load(ACTIVE)

    exp = datetime.fromisoformat(active["expires_at_utc"].replace("Z", "+00:00"))
    if utcnow() > exp:
        raise SystemExit(f"active_candidate_expired: expired_at={active['expires_at_utc']} (re-run discover/prepare)")

    status = status.strip().lower()
    if status not in {"posted", "aborted"}:
        raise SystemExit("invalid_status: must be posted|aborted")

    comment_url_norm = (comment_url or "").strip() or None
    verify = {"ok": None, "detail": None}
    if status == "posted":
        if not comment_url_norm:
            raise SystemExit("posted_requires_comment_url")
        if not _validate_comment_url(comment_url_norm):
            raise SystemExit("invalid_comment_url: expected a reddit.com comment permalink")
        ok, detail = _best_effort_verify_url(comment_url_norm)
        verify = {"ok": ok, "detail": detail}
        if not ok:
            raise SystemExit(f"comment_url_not_verifiable: {detail}")

    row = {
        "ts_utc": _human_ts(utcnow()),
        "status": status,
        "run_id": active.get("run_id"),
        "post_id": active.get("post_id"),
        "subreddit": active.get("subreddit"),
        "thread_url": active.get("thread_url"),
        "comment_url": comment_url_norm,
        "draft_comment": active.get("draft_comment"),
        "final_text": (final_text or "").strip() or None,
        "note": (note or "").strip() or None,
        "verify": verify,
    }
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    with LEDGER.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")

    # Clear active candidate after a terminal action.
    try:
        ACTIVE.unlink()
    except Exception:
        pass

    return row


def print_run_summary(run: dict[str, Any]):
    print(f"run_id={run['run_id']} generated_at={run['generated_at_utc']} expires_at={run['expires_at_utc']} count={run['count']}")
    if not run.get("candidates"):
        print("no_candidates")
        return
    for i, c in enumerate(run["candidates"], start=1):
        url = c.get("permalink")
        print(f"[{i}] post_id={c.get('post_id')} r/{c.get('subreddit')} age_h={c.get('age_hours')} comments={c.get('num_comments')}")
        print(f"    url={url}")


def print_prepare_checklist(active: dict[str, Any]):
    print("selected_ok")
    print(f"post_id={active['post_id']} subreddit={active.get('subreddit')} thread={active.get('thread_url')}")
    print("\nDRAFT (edit as needed; do not claim personal experience you don't have):\n")
    print(active.get("draft_comment") or "")
    print("\nMANUAL CHECKLIST:")
    print("- Open the thread URL and read OP + top comments (live context).")
    print("- Confirm subreddit rules (self-promo, medical advice norms).")
    print("- Make one deliberate comment (no automation).")
    print("- Copy the final comment permalink.")
    print("- Log it:\n    python3 scripts/reddit_manual_ops.py log --status posted --comment-url '<PASTE_URL>' --final-text '<PASTE_FINAL_TEXT>'")
    print("\nIf you decide not to post:")
    print("    python3 scripts/reddit_manual_ops.py log --status aborted --note 'why'\n")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=textwrap.dedent(
            """\
            Manual-only Reddit ops.

            This script does NOT perform authenticated actions.
            """
        ),
    )
    sub = ap.add_subparsers(dest="cmd", required=True)

    ap_d = sub.add_parser("discover", help="Discover fresh candidates and write a run file")
    ap_d.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    ap_d.add_argument("--expires-min", type=int, default=DEFAULT_EXPIRES_MIN)

    ap_p = sub.add_parser("prepare", help="Select exactly one candidate from a fresh run")
    ap_p.add_argument("--run", required=True, help="Path to run JSON from discover")
    ap_p.add_argument("--post-id", required=True)

    ap_l = sub.add_parser("log", help="Log a posted or aborted manual action for the active candidate")
    ap_l.add_argument("--status", required=True, help="posted|aborted")
    ap_l.add_argument("--comment-url", default=None)
    ap_l.add_argument("--final-text", default=None)
    ap_l.add_argument("--note", default=None)

    ap_s = sub.add_parser("show-active", help="Print the currently prepared candidate")

    args = ap.parse_args(argv)

    if args.cmd == "discover":
        res = discover(limit=args.limit, expires_min=args.expires_min)
        run = res["run"]
        print(f"run_path={res['path']}")
        print_run_summary(run)
        return 0

    if args.cmd == "prepare":
        active = prepare(Path(args.run), args.post_id)
        print_prepare_checklist(active)
        return 0

    if args.cmd == "log":
        row = log_action(args.status, args.comment_url, args.final_text, args.note)
        print("logged_ok")
        print(json.dumps(row, ensure_ascii=False, indent=2))
        return 0

    if args.cmd == "show-active":
        if not ACTIVE.exists():
            print("no_active")
            return 0
        print(ACTIVE.read_text(encoding="utf-8"))
        return 0

    raise SystemExit("unknown_cmd")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
