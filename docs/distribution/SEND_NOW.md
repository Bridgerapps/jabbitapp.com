# SEND_NOW (manual distribution)

If you have 15 minutes, do this. No new lead sourcing until `ready_to_send` is empty.

## 0) See what’s ready

```bash
bash scripts/manual-growth-loop/ready-to-send.sh
```

## Sender boundary (hard rule)

Jabbit outbound must **never** send from any Adprax domain/sender.
If you’re using any automated sender, sanity-check before sending:

```bash
bash scripts/manual-growth-loop/guard-no-adprax-sender.sh
```

## 1) Open the current copy/paste brief (always use “latest”)

- `docs/distribution/send-now-brief-latest.md`
- Optional copy/paste pack: `docs/send-now-pack-latest.txt`

Send the **top 3** first (it’s already ordered).

## 2) Immediately mark each send as sent (so we don’t re-send)

After each message goes out:

```bash
bash scripts/manual-growth-loop/mark-sendqueue-sent.sh <ledger_send_id> --yes
```

## 3) Owner backlog (not blocking the loop, but still real)

- `docs/distribution/awaiting-owner-queue-2026-03-14-1206Z.md`

## 4) If you still have time (next highest leverage)

Do 3 quick manual app directory submissions:
- pack: `docs/distribution/app-directory-submission-pack-2026-03-14.md`
- checklist: `docs/distribution/app-directory-submission-checklist-2026-03-14.md`

## 5) What’s next

```bash
bash scripts/manual-growth-loop/ledger-next.sh
```
