#!/usr/bin/env bash
set -euo pipefail

# Generate docs/send-now-mailto-links-YYYY-MM-DD.md (+ latest symlink) from
# docs/send-now-pack-latest.txt.
#
# Goal: remove friction for the ONLY thing that matters when the loop is STOP'd:
# manual sends + marking them sent.

ROOT="/home/jabbit/.openclaw/workspace"
PACK="${1:-$ROOT/docs/send-now-pack-latest.txt}"
OUT_DATE="${OUT_DATE:-$(date -u +%F)}"
OUT="$ROOT/docs/send-now-mailto-links-${OUT_DATE}.md"
OUT_LATEST="$ROOT/docs/send-now-mailto-links-latest.md"

if [[ ! -f "$PACK" ]]; then
  echo "ERR: missing pack: $PACK" >&2
  exit 2
fi

python3 - "$PACK" "$OUT" <<'PY'
import re
import sys
from urllib.parse import quote
from pathlib import Path

pack_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
text = pack_path.read_text(encoding='utf-8')

# Parse sections like:
# ### 2) Email — On The Pen (dave@onthepen.com)
# Subject: ...
# Body (paste as-is):
# ...

email_blocks = []

header_re = re.compile(r"^###\s+\d+\)\s+Email\s+—\s+(.+?)\s+\(([^)]+@[^)]+)\)\s*$", re.M)

# We'll split by headers and parse each chunk.
headers = list(header_re.finditer(text))
for i, h in enumerate(headers):
    name = h.group(1).strip()
    to = h.group(2).strip()
    start = h.end()
    end = headers[i+1].start() if i+1 < len(headers) else len(text)
    chunk = text[start:end]

    subj_m = re.search(r"^Subject:\s*(.+?)\s*$", chunk, re.M)
    if not subj_m:
        # If we can't find a subject, skip (shouldn't happen for Email sections)
        continue
    subject = subj_m.group(1).strip()

    # Body label can be "Body" or occasionally "Message".
    body_m = re.search(r"^(Body|Message)\s*\(paste as-is\):\s*$", chunk, re.M)
    if not body_m:
        continue
    body_start = body_m.end()

    # Body ends right before "After send:" or end-of-chunk
    after_m = re.search(r"^After send:\s*$", chunk, re.M)
    body_end = after_m.start() if after_m else len(chunk)
    body = chunk[body_start:body_end].strip("\n")

    # mailto: encode subject/body; preserve newlines as %0A via quote
    mailto = f"mailto:{to}?subject={quote(subject)}&body={quote(body + '\n')}"

    email_blocks.append({
        'name': name,
        'to': to,
        'subject': subject,
        'mailto': mailto,
    })

lines = []
m = re.search(r"send-now-mailto-links-(\d{4}-\d{2}-\d{2})", out_path.name)
date_label = m.group(1) if m else out_path.name
lines.append(f"# Send-now mailto links — {date_label}")
lines.append("")
lines.append("These open a prefilled email draft in your default mail client. (Double-check formatting before sending.)")
lines.append("")
lines.append(f"Source copy: {pack_path.as_posix()}")

if not email_blocks:
    lines.append("")
    lines.append("(No email blocks found in the send-now pack.)")
else:
    for b in email_blocks:
        lines.append("")
        lines.append(f"## {b['name']}")
        lines.append(f"- to: `{b['to']}`")
        lines.append("- ledger: (see docs/send-now-pack-latest.txt for mark-sent command)")
        lines.append(f"- mailto: {b['mailto']}")

out_path.write_text("\n".join(lines) + "\n", encoding='utf-8')
print(f"WROTE: {out_path}")
print(f"EMAIL_BLOCKS: {len(email_blocks)}")
PY

ln -sf "$(basename "$OUT")" "$OUT_LATEST"
echo "OK: linked $OUT_LATEST -> $(basename "$OUT")"
