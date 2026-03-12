# SEND_NOW (manual distribution)

If you have 15 minutes, do this. No new lead sourcing until `ready_to_send` is empty.

## 0) See what’s ready

```bash
bash scripts/manual-growth-loop/ready-to-send.sh
```

## 1) Open the current copy/paste brief

- `docs/distribution/send-now-brief-2026-03-12-1117Z.md`

Send the **top 3** first (it’s already ordered).

## 2) Immediately mark each send as sent (so we don’t re-send)

After each message goes out:

```bash
bash scripts/manual-growth-loop/mark-sendqueue-sent.sh <ledger_send_id> --yes
```

## 3) What’s next / follow-ups

```bash
bash scripts/manual-growth-loop/ledger-next.sh
```

If `ready_to_send` is empty, *then* generate more targets. Until then, ship the backlog.
