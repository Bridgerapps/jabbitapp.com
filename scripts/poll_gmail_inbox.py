#!/usr/bin/env python3
import base64
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

STATE_PATH = Path("/home/jabbit/.openclaw/workspace/data/email/inbox_state.json")
TOKEN_PATH = Path(os.path.expanduser(os.getenv("GMAIL_OAUTH_TOKEN_PATH", "~/.openclaw/credentials/gmail_token.json")))
CLIENT_PATH = Path(os.path.expanduser(os.getenv("GMAIL_OAUTH_CLIENT_PATH", "~/.openclaw/credentials/gmail_oauth.json")))
SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"]
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
    "jabbit@bridgerapps.com",
}


def load_state():
    if STATE_PATH.exists():
        try:
            return json.loads(STATE_PATH.read_text())
        except Exception:
            pass
    return {"last_history_id": 0}


def save_state(st):
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(st, indent=2))


def extract_emails(raw_sender: str) -> set[str]:
    return {e.lower() for e in re.findall(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", raw_sender or "")}


def is_promotional(sender: str, subject: str, blob: str, otp: str | None) -> bool:
    sender_l = sender.lower()
    subject_l = subject.lower()

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
    return bool(extract_emails(sender) & SELF_SENDERS)


def b64url_decode(data: str) -> str:
    if not data:
        return ""
    padded = data + "=" * (-len(data) % 4)
    try:
        return base64.urlsafe_b64decode(padded.encode("utf-8")).decode("utf-8", errors="ignore")
    except Exception:
        return ""


def get_header(headers: list[dict], name: str) -> str:
    target = name.lower()
    for h in headers or []:
        if (h.get("name") or "").lower() == target:
            return h.get("value") or ""
    return ""


def extract_text_from_payload(payload: dict) -> str:
    if not payload:
        return ""

    mime = (payload.get("mimeType") or "").lower()
    body_data = ((payload.get("body") or {}).get("data") or "")

    if mime == "text/plain" and body_data:
        return b64url_decode(body_data)

    parts = payload.get("parts") or []
    for p in parts:
        txt = extract_text_from_payload(p)
        if txt:
            return txt

    if body_data:
        return b64url_decode(body_data)

    return ""


def get_gmail_service():
    if not TOKEN_PATH.exists():
        raise RuntimeError(f"gmail token file not found: {TOKEN_PATH}")
    if not CLIENT_PATH.exists():
        raise RuntimeError(f"gmail oauth client file not found: {CLIENT_PATH}")

    creds = Credentials.from_authorized_user_file(str(TOKEN_PATH), SCOPES)

    if not creds.valid:
        if creds.expired and creds.refresh_token:
            creds.refresh(Request())
            TOKEN_PATH.write_text(creds.to_json())
        else:
            raise RuntimeError("gmail oauth credentials invalid and cannot refresh")

    return build("gmail", "v1", credentials=creds, cache_discovery=False)


def fetch_new_message_ids(service, start_history_id: int):
    ids = set()
    req = service.users().history().list(
        userId="me",
        startHistoryId=str(start_history_id),
        historyTypes=["messageAdded"],
        labelId="INBOX",
        maxResults=200,
    )

    while req is not None:
        resp = req.execute()
        for h in resp.get("history", []) or []:
            for added in h.get("messagesAdded", []) or []:
                m = added.get("message") or {}
                mid = m.get("id")
                if mid:
                    ids.add(mid)
        req = service.users().history().list_next(req, resp)

    return list(ids)


def main():
    st = load_state()
    last_history_id = int(st.get("last_history_id", 0) or 0)

    try:
        service = get_gmail_service()
        profile = service.users().getProfile(userId="me").execute()
        current_history_id = int(profile.get("historyId", 0) or 0)

        # First run after migration or missing state: initialize baseline, do not backfill-alert.
        if last_history_id <= 0:
            st["last_history_id"] = current_history_id
            st["last_check_utc"] = datetime.now(timezone.utc).isoformat()
            st["mode"] = "gmail_oauth"
            save_state(st)
            print(json.dumps({"ok": True, "new": 0, "suppressed": 0, "messages": [], "initialized": True}))
            return

        try:
            msg_ids = fetch_new_message_ids(service, last_history_id)
        except HttpError as e:
            # Gmail can return 404 when startHistoryId is too old; re-baseline safely.
            if getattr(e, "status_code", None) == 404 or "startHistoryId" in str(e):
                st["last_history_id"] = current_history_id
                st["last_check_utc"] = datetime.now(timezone.utc).isoformat()
                st["mode"] = "gmail_oauth"
                save_state(st)
                print(json.dumps({"ok": True, "new": 0, "suppressed": 0, "messages": [], "rebased": True}))
                return
            raise

        # Oldest-first processing for stable chronology.
        msg_ids = msg_ids[-MAX_FETCH:]

        messages = []
        suppressed = 0

        for mid in msg_ids:
            msg = service.users().messages().get(userId="me", id=mid, format="full").execute()
            payload = msg.get("payload") or {}
            headers = payload.get("headers") or []

            subject = get_header(headers, "Subject")
            sender = get_header(headers, "From")
            date = get_header(headers, "Date")
            internal_date_ms = int(msg.get("internalDate", "0") or "0")

            body = extract_text_from_payload(payload)[:3000]
            snippet = (msg.get("snippet") or "")
            blob = f"{subject}\n{body}\n{snippet}".lower()

            otp = None
            if any(k in blob for k in KEYWORDS):
                m_otp = OTP_RE.search(blob)
                if m_otp:
                    otp = m_otp.group(1)

            if is_promotional(sender, subject, blob, otp) or is_self_sent(sender):
                suppressed += 1
                continue

            iso_dt = ""
            if internal_date_ms > 0:
                iso_dt = datetime.fromtimestamp(internal_date_ms / 1000, tz=timezone.utc).isoformat()

            messages.append({
                "id": mid,
                "from": sender,
                "subject": subject,
                "date": date or iso_dt,
                "otp": otp,
                "snippet": re.sub(r"\s+", " ", (body or snippet).strip())[:220],
            })

        st["last_history_id"] = current_history_id
        st["last_check_utc"] = datetime.now(timezone.utc).isoformat()
        st["mode"] = "gmail_oauth"
        save_state(st)

        print(json.dumps({"ok": True, "new": len(messages), "suppressed": suppressed, "messages": messages}, ensure_ascii=False))

    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e), "mode": "gmail_oauth"}))


if __name__ == "__main__":
    main()
