#!/usr/bin/env python3
"""Visible "Published / Updated" dateline + breadcrumb <nav> for article-template pages.

AEO/freshness: answer engines favour pages that show when they were published and last
updated. For every page that uses /assets/article.css and has a JSON-LD dateModified:
  * datePublished: JSON-LD datePublished if present, else the date git first added the
    file (inserted into the JSON-LD next to dateModified).
  * a <p class="dateline">Published <time> · Updated <time></p> right above the <h1>
    (replaced in place if it already exists, so re-running after dateModified changes is safe).
  * the "Home / ..." breadcrumb paragraph is wrapped in <nav aria-label="Breadcrumb">.
Pages without dateModified are left alone (no invented dates).

Generators in ops/scripts/pages/*.py write pages without this line: run this after any
regeneration.   Usage: dateline-sync.py --root site [--check]
"""
import argparse, json, os, re, subprocess, sys
from datetime import date

SKIP = {'node_modules', 'docs', 'output', 'scripts', 'data', '_includes', '.git', 'jabbit', 'jabbitapp.com'}
LD_RE = re.compile(r'(<script[^>]*type="application/ld\+json"[^>]*>)(.*?)(</script>)', re.S)
DL_RE = re.compile(r'<p class="dateline">.*?</p>\n?', re.S)
BC_RE = re.compile(r'(?<!<nav aria-label="Breadcrumb">)<p><a href="/">Home</a>(?:(?!</p>).)*</p>', re.S)

def human(d):
    y, m, dd = map(int, d.split('-'))
    return date(y, m, dd).strftime('%B ') + str(dd) + date(y, m, dd).strftime(', %Y')

def objs(ld):
    if isinstance(ld, list):
        for o in ld: yield from objs(o)
    elif isinstance(ld, dict):
        if '@graph' in ld: yield from objs(ld['@graph'])
        else: yield ld

def git_added(root, rel):
    out = subprocess.run(['git', '-C', root, 'log', '--diff-filter=A', '--follow', '--format=%ad',
                          '--date=short', '--', rel], capture_output=True, text=True).stdout.split()
    return out[-1] if out else None

def process(root, rel):
    path = os.path.join(root, rel)
    s = open(path, encoding='utf-8').read()
    if '/assets/article.css' not in s or '<h1' not in s:
        return None
    pub = mod = None
    for m in LD_RE.finditer(s):
        try: ld = json.loads(m.group(2))
        except Exception: continue
        for o in objs(ld):
            if o.get('@type') == 'BreadcrumbList': continue
            mod = mod or o.get('dateModified')
            pub = pub or o.get('datePublished')
    if not mod:
        return None
    mod = mod[:10]
    new = s
    if not pub:
        pub = git_added(root, rel)
        if not pub: return None
        # add datePublished beside the first dateModified inside JSON-LD
        def add_pub(m):
            body = m.group(2)
            if '"dateModified"' not in body or '"datePublished"' in body: return m.group(0)
            body2 = re.sub(r'("dateModified"\s*:\s*"[^"]+")', '"datePublished": "%s", \\1' % pub, body, count=1)
            json.loads(body2)
            return m.group(1) + body2 + m.group(3)
        new = LD_RE.sub(add_pub, new)
    pub = pub[:10]
    if pub > mod: pub = mod
    line = ('<p class="dateline">Published <time datetime="%s">%s</time> · Updated '
            '<time datetime="%s">%s</time></p>\n') % (pub, human(pub), mod, human(mod))
    if DL_RE.search(new):
        new = DL_RE.sub(lambda m: line, new, count=1)
    else:
        i = new.index('<h1')
        new = new[:i] + line + new[i:]
    main_i = new.find('<main')
    if main_i != -1:
        head, tail = new[:main_i], new[main_i:]
        tail = BC_RE.sub(lambda m: '<nav aria-label="Breadcrumb">' + m.group(0) + '</nav>', tail, count=1)
        new = head + tail
    if new != s:
        return path, new
    return None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', default='.')
    ap.add_argument('--check', action='store_true')
    a = ap.parse_args()
    changed = []
    for d, ds, fs in os.walk(a.root):
        ds[:] = [x for x in ds if x not in SKIP]
        for f in sorted(fs):
            if not f.endswith('.html'): continue
            rel = os.path.relpath(os.path.join(d, f), a.root)
            r = process(a.root, rel)
            if r:
                changed.append(rel)
                if not a.check: open(r[0], 'w', encoding='utf-8').write(r[1])
    print(('would change' if a.check else 'changed'), len(changed), 'file(s)')
    for c in changed: print(' ', c)
    sys.exit(1 if (a.check and changed) else 0)

if __name__ == '__main__':
    main()
