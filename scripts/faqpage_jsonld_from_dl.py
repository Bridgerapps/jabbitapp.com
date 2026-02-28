#!/usr/bin/env python3
"""Generate schema.org FAQPage JSON-LD from <dl class="faq"> dt/dd pairs.

Usage:
  scripts/faqpage_jsonld_from_dl.py path/to/page.html
  scripts/faqpage_jsonld_from_dl.py path/to/page.html --inplace

Behavior:
- Default: prints a full <script type="application/ld+json">...</script> block to stdout.
- With --inplace: injects (or replaces) a JSON-LD <script> block in the HTML file.

Notes:
- Uses Python stdlib only.
- Extracts text content from the first <dl> element whose class attribute contains "faq".
- For idempotency, --inplace targets a script tag by id (default: faq-jsonld).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from html.parser import HTMLParser


_WHITESPACE_RE = re.compile(r"\s+")


def _norm_text(s: str) -> str:
    s = _WHITESPACE_RE.sub(" ", s)
    return s.strip()


class FaqDLParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self._in_script_style = 0

        self._faq_dl_depth: int | None = None
        self._dl_depth = 0

        self._capture_tag: str | None = None  # 'dt' or 'dd'
        self._buf: list[str] = []

        self._pending_q: str | None = None
        self.pairs: list[tuple[str, str]] = []

    @staticmethod
    def _has_faq_class(attrs: list[tuple[str, str | None]]) -> bool:
        for k, v in attrs:
            if k.lower() == "class" and v:
                classes = {c.strip() for c in v.split() if c.strip()}
                if "faq" in classes:
                    return True
        return False

    def handle_starttag(self, tag: str, attrs):
        t = tag.lower()

        if t in ("script", "style"):
            self._in_script_style += 1
            return

        if t == "dl":
            self._dl_depth += 1
            if self._faq_dl_depth is None and self._has_faq_class(attrs):
                self._faq_dl_depth = self._dl_depth
            return

        if self._faq_dl_depth is None:
            return

        # Only capture within the selected faq dl.
        if self._dl_depth < self._faq_dl_depth:
            return

        if t in ("dt", "dd"):
            self._capture_tag = t
            self._buf = []

    def handle_endtag(self, tag: str):
        t = tag.lower()

        if t in ("script", "style"):
            if self._in_script_style:
                self._in_script_style -= 1
            return

        if t == "dl":
            if self._dl_depth:
                self._dl_depth -= 1
            if self._faq_dl_depth is not None and self._dl_depth < self._faq_dl_depth:
                self._faq_dl_depth = None
            return

        if self._faq_dl_depth is None:
            return

        if t == self._capture_tag:
            text = _norm_text("".join(self._buf))
            self._buf = []
            self._capture_tag = None

            if t == "dt":
                self._pending_q = text or None
            elif t == "dd":
                if self._pending_q and text:
                    self.pairs.append((self._pending_q, text))
                self._pending_q = None

    def handle_data(self, data: str):
        if self._in_script_style:
            return
        if self._faq_dl_depth is None:
            return
        if self._capture_tag in ("dt", "dd"):
            self._buf.append(data)

    def error(self, message):  # pragma: no cover
        raise RuntimeError(message)


def extract_faq_pairs(html: str) -> list[tuple[str, str]]:
    parser = FaqDLParser()
    parser.feed(html)
    return parser.pairs


def build_faqpage_jsonld(pairs: list[tuple[str, str]]):
    return {
        "@context": "https://schema.org",
        "@type": "FAQPage",
        "mainEntity": [
            {
                "@type": "Question",
                "name": q,
                "acceptedAnswer": {"@type": "Answer", "text": a},
            }
            for q, a in pairs
        ],
    }


def render_jsonld_script(data, *, indent: int, script_id: str | None) -> str:
    json_str = json.dumps(data, ensure_ascii=False, indent=(indent or None))
    # Verify we emitted valid JSON (paranoia / future edits).
    json.loads(json_str)

    id_attr = f' id="{script_id}"' if script_id else ""
    return "\n".join(
        [
            f'<script type="application/ld+json"{id_attr}>',
            json_str,
            "</script>",
            "",
        ]
    )


def _replace_or_insert_script(html: str, *, script_id: str, script_block: str) -> tuple[str, bool]:
    # Replace existing script with the same id, if present.
    # Non-greedy DOTALL to cover pretty-printed JSON.
    pat = re.compile(
        r"<script(?P<attrs>[^>]*?)>\\s*(?P<body>.*?)\\s*</script>",
        flags=re.IGNORECASE | re.DOTALL,
    )

    def is_target(attrs: str) -> bool:
        attrs_l = attrs.lower()
        if "application/ld+json" not in attrs_l:
            return False
        # Require explicit id match for safety.
        return re.search(rf"\\bid=['\"]{re.escape(script_id)}['\"]", attrs, flags=re.IGNORECASE) is not None

    m = None
    for cand in pat.finditer(html):
        if is_target(cand.group("attrs")):
            m = cand
            break

    if m:
        new_html = html[: m.start()] + script_block + html[m.end() :]
        return new_html, True

    # Otherwise insert into <head> if possible, else before </body>, else append.
    lower = html.lower()
    head_close = lower.find("</head>")
    if head_close != -1:
        return html[:head_close] + script_block + html[head_close:], True

    body_close = lower.find("</body>")
    if body_close != -1:
        return html[:body_close] + script_block + html[body_close:], True

    return html + "\n" + script_block, True


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("html_file", help="Path to an HTML file containing a <dl class=faq>.")
    ap.add_argument(
        "--indent",
        type=int,
        default=2,
        help="JSON indent level (default: 2). Use 0 for compact.",
    )
    ap.add_argument(
        "--script-id",
        default="faq-jsonld",
        help='id="..." on the script tag (default: faq-jsonld). Use empty string for none (print-only mode).',
    )
    ap.add_argument(
        "--inplace",
        action="store_true",
        help="Inject (or replace) the JSON-LD script block into the HTML file.",
    )
    args = ap.parse_args(argv)

    path = args.html_file
    html = open(path, "r", encoding="utf-8").read()

    pairs = extract_faq_pairs(html)
    if not pairs:
        print(
            f"No FAQ dt/dd pairs found in <dl class=faq> within: {path}",
            file=sys.stderr,
        )
        return 2

    data = build_faqpage_jsonld(pairs)

    # In print-only mode, allow removing the id attribute.
    script_id: str | None
    if args.inplace:
        # For inplace we keep an id by default; it's how we stay idempotent.
        if not args.script_id:
            print("--inplace requires a non-empty --script-id", file=sys.stderr)
            return 2
        script_id = args.script_id
    else:
        script_id = args.script_id or None

    script_block = render_jsonld_script(data, indent=args.indent, script_id=script_id)

    if not args.inplace:
        sys.stdout.write(script_block)
        return 0

    new_html, changed = _replace_or_insert_script(html, script_id=args.script_id, script_block=script_block)
    if changed and new_html != html:
        open(path, "w", encoding="utf-8").write(new_html)
        print(f"faq_jsonld_inject: wrote={path} pairs={len(pairs)}", file=sys.stderr)
    else:
        print(f"faq_jsonld_inject: no_change={path} pairs={len(pairs)}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
