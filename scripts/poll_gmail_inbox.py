#!/usr/bin/env python3
import imaplib
import email
import json
import os
import re
from datetime import datetime, timezone
from email.header import decode_header
from pathlib import Path

EMAIL_ADDR = os.getenv("GMAIL_INBOX_USER", "jabbit@bridgerapps.com")
APP_PASSWORD = os.getenv("GMAIL_APP_PASSWORD", "")
STATE_PATH = Path("/home/jabbit/.openclaw/workspace/data/email/inbox_state.json")
MAX_FETCH = int(os.getenv("GMAIL_POLL_MAX", "20"))

OTP_RE = re.compile(r"\b(\d{4,8})\b")
KEYWORDS = ("code", "otp", "verify", "verification", "login", "2fa", "security")

PROMO_FROM_MARKERS = (
    "workspace-noreply@google.com",
    "newsletter",
    "marketing",
)
PROMO_SUBJECT_MARKERS = (
    "unlock",
    "easily",
    "tips",
    "newsletter",
    "webinar",
    "digest",
    "new feature",
    "product update",
    "better meetings",
    "engaging videos",
)
IMPORTANT_MARKERS = (
    "otp",
    "verify",
    "verification",
    "security",
    "suspicious",
    "password",
    "login",
    "2fa",
    "invoice",
    "receipt",
    "payment",
    "billing",
    "failed",
    "error",
    "urgent",
)
SELF_SENDERS = {
    "jon@bridgerapps.com",
}


def dec(v: str) -> str:
    if not v:
        return ""
    out = []
    for part, enc in decode_header(v):
        if isinstance(part, bytes):
            out.append(part.decode(enc or "utf-8", errors="ignore"))
        else:
            out.append(part)
    return "".join(out)


def load_state():
    if STATE_PATH.exists():
        return json.loads(STATE_PATH.read_text())
    return {"last_uid": 0}


def save_state(st):
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(st, indent=2))


def extract_text(msg):
    if msg.is_multipart():
        for p in msg.walk():
            ctype = p.get_content_type()
            if ctype == "text/plain":
                try:
                    return p.get_payload(decode=True).decode(errors="ignore")
                except Exception:
                    continue
    else:
        try:
            return msg.get_payload(decode=True).decode(errors="ignore")
        except Exception:
            return ""
    return ""


def extract_emails(raw_sender: str) -> set[str]:
    return {e.lower() for e in re.findall(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", raw_sender or "")}


def is_promotional(sender: str, subject: str, blob: str, otp: str | None) -> bool:
    sender_l = sender.lower()
    subject_l = subject.lower()

    # Important/security/billing mail should never be suppressed.
    if otp or any(m in blob for m in IMPORTANT_MARKERS):
        return False

    sender_flag = (
        any(m in sender_l for m in PROMO_FROM_MARKERS)
        or "noreply" in sender_l
        or "no-reply" in sender_l
    )
    subject_flag = any(m in subject_l for m in PROMO_SUBJECT_MARKERS)

    return sender_flag and subject_flag


def is_self_sent(sender: str) -> bool:
    sender_emails = extract_emails(sender)
    local_self = {EMAIL_ADDR.lower(), *SELF_SENDERS}
    return bool(sender_emails & local_self)


def main():
    if not APP_PASSWORD:
        print(json.dumps({"ok": False, "error": "GMAIL_APP_PASSWORD not set"}))
        return

    st = load_state()
    last_uid = int(st.get("last_uid", 0))

    m = imaplib.IMAP4_SSL("imap.gmail.com")
    m.login(EMAIL_ADDR, APP_PASSWORD)
    m.select("INBOX")
    # Robust UID fetch: get ALL UIDs and filter in Python (Gmail UID ranges can be tricky)
    typ, data = m.uid("search", None, "ALL")
    if typ != "OK":
        print(json.dumps({"ok": False, "error": "imap search failed"}))
        return

    all_uids = [int(u) for u in data[0].split() if u]
    if not all_uids:
        print(json.dumps({"ok": True, "new": 0, "messages": []}))
        return

    # Filter to only new UIDs greater than last_uid
    uids = [u for u in all_uids if u > last_uid]
    if not uids:
        print(json.dumps({"ok": True, "new": 0, "messages": []}))
        return

    uids = uids[-MAX_FETCH:]
    messages = []
    max_uid = last_uid
    suppressed = 0

    for uid in uids:
        uid_i = int(uid)
        max_uid = max(max_uid, uid_i)
        # imaplib expects UID as str/bytes (not int)
        typ, msg_data = m.uid("fetch", str(uid_i), "(RFC822)")
        if typ != "OK" or not msg_data or not msg_data[0]:
            continue
        raw = msg_data[0][1]
        msg = email.message_from_bytes(raw)
        subj = dec(msg.get("Subject", ""))
        sender = dec(msg.get("From", ""))
        date = dec(msg.get("Date", ""))
        body = extract_text(msg)[:3000]

        blob = f"{subj}\n{body}".lower()
        otp = None
        if any(k in blob for k in KEYWORDS):
            m_otp = OTP_RE.search(blob)
            if m_otp:
                otp = m_otp.group(1)

        # Suppress obvious noise (promo + your own test sends).
        if is_promotional(sender, subj, blob, otp) or is_self_sent(sender):
            suppressed += 1
            continue

        messages.append({
            "uid": uid_i,
            "from": sender,
            "subject": subj,
            "date": date,
            "otp": otp,
            "snippet": re.sub(r"\s+", " ", body.strip())[:220],
        })

    st["last_uid"] = max_uid
    st["last_check_utc"] = datetime.now(timezone.utc).isoformat()
    save_state(st)

    print(json.dumps({"ok": True, "new": len(messages), "suppressed": suppressed, "messages": messages}, ensure_ascii=False))


if __name__ == "__main__":
    main()
