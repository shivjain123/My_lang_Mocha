#!/usr/bin/env python3
"""
mocha_specgen.py - build spec library tables straight from lib/*.mch source.

Usage:
    python mocha_specgen.py lib/mocha-astro.mch [more.mch ...]
    python mocha_specgen.py --all lib          (every lib/mocha-*.mch)

Writes spec_gen/<library>.md for each library plus spec_gen/_summary.md.
It only READS your library sources. It never touches the compiler,
codegen or RC code.

Rules:
  * `~~` lines directly above a function are its doc comment.
  * `@param name text` and `@return text` lines are picked up too.
  * `private` / `local` functions and native helpers named c_* are hidden.
  * A doc block that lands on a hidden first function (or sits alone at the
    top of the file) becomes the library overview.
  * Functions inside `extend T { ... }` are shown as `T.name`.
  * Comment lines are joined with a plain space (no stray ". " in the middle
    of a sentence).
  * Functions with no doc comment still get a row, with an empty description.
"""
import glob
import os
import re
import sys

FUNC_START = re.compile(r'^\s*((?:(?:private|local)\s+)*)function\s+(\w+)\s*\(')
EXTEND = re.compile(r'^\s*extend\s+(.+?)\s*\{')


def split_top(s, sep=','):
    parts, depth, cur = [], 0, ''
    for ch in s:
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        if ch == sep and depth == 0:
            parts.append(cur.strip())
            cur = ''
        else:
            cur += ch
    if cur.strip():
        parts.append(cur.strip())
    return parts


def parse_function(line):
    m = FUNC_START.match(line)
    if not m:
        return None
    mods = m.group(1).split()
    name = m.group(2)
    i = m.end()
    depth, j = 1, i
    while j < len(line) and depth > 0:
        if line[j] == '(':
            depth += 1
        elif line[j] == ')':
            depth -= 1
        j += 1
    params = split_top(line[i:j - 1])
    rest = line[j:].strip()
    has_arrow = rest.startswith('->')
    if has_arrow:
        rest = rest[2:].strip()
    native = None
    mn = re.search(r'\bnative\s+(\w+)\s*;?\s*$', rest)
    if mn:
        native = mn.group(1)
        rest = rest[:mn.start()]
    ret = rest.strip().rstrip(';{').strip() if has_arrow else ''
    return {
        'mods': mods, 'name': name, 'params': params,
        'ret': ret or 'null', 'native': native,
    }


def clean_for_braces(line):
    line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
    return re.split(r'//|~~', line)[0]


def split_doc(lines):
    """Return (prose, {param: text}, return_text)."""
    prose, params, ret = [], {}, ''
    for ln in lines:
        t = ln.strip()
        if t.startswith('@param'):
            bits = t.split(None, 2)
            if len(bits) >= 2:
                params[bits[1]] = bits[2].strip() if len(bits) > 2 else ''
        elif t.startswith('@return'):
            bits = t.split(None, 1)
            ret = bits[1].strip() if len(bits) > 1 else ''
        else:
            prose.append(t)
    return re.sub(r'\s+', ' ', ' '.join(prose)).strip(), params, ret


def parse_file(path):
    funcs, overview = [], None
    pending, pending_blank = [], False
    seen_function = False
    in_triple, triple_buf = False, []
    owner, owner_depth = None, 0

    def take_overview(lines):
        nonlocal overview
        if overview is None and not seen_function and lines:
            text = split_doc(lines)[0]
            if text:
                overview = text

    with open(path, encoding='utf-8', errors='replace') as fh:
        for raw in fh:
            line = raw.rstrip('\n')
            s = line.strip()

            if in_triple:
                if '"""' in s:
                    triple_buf.append(s.split('"""')[0])
                    in_triple = False
                    para = []
                    for t in triple_buf:
                        if not t.strip() and para:
                            break
                        if t.strip():
                            para.append(t)
                    take_overview(para)
                    triple_buf = []
                else:
                    triple_buf.append(s)
                continue
            if s.startswith('"""'):
                body = s[3:]
                if '"""' in body:
                    take_overview([body.split('"""')[0]])
                else:
                    in_triple, triple_buf = True, [body]
                continue

            if s.startswith('~~'):
                txt = s[2:]
                if txt.startswith(' '):
                    txt = txt[1:]
                if pending and pending_blank:
                    take_overview(pending)
                    pending = []
                pending.append(txt)
                pending_blank = False
                continue
            if s == '':
                if pending:
                    pending_blank = True
                continue
            if s.startswith('//'):
                continue

            code = clean_for_braces(line)
            em = EXTEND.match(line)
            if em and owner is None:
                owner, owner_depth = em.group(1).strip(), 0

            fn = parse_function(line)
            if fn:
                hidden = ('private' in fn['mods'] or 'local' in fn['mods']
                          or (fn['native'] and fn['name'].startswith('c_')))
                doc = pending
                if hidden and not seen_function and doc and overview is None:
                    take_overview(doc)
                    doc = []
                fn['doc'] = doc
                fn['hidden'] = bool(hidden)
                fn['owner'] = owner
                funcs.append(fn)
                seen_function = True
            elif pending:
                take_overview(pending)
            pending, pending_blank = [], False

            if owner is not None:
                owner_depth += code.count('{') - code.count('}')
                if owner_depth <= 0:
                    owner = None
    return overview, funcs


def esc(s):
    return s.replace('|', '\\|')


def render(libname, overview, funcs):
    public = [f for f in funcs if not f['hidden']]
    hidden = [f for f in funcs if f['hidden']]
    rows, undocumented = [], []
    for f in public:
        prose, pdocs, rdoc = split_doc(f['doc'])
        label = f"{f['owner']}.{f['name']}" if f['owner'] else f['name']
        params = ', '.join(f['params']) if f['params'] else '-'
        desc = prose
        notes = [f'`{k}`: {v}' for k, v in pdocs.items()]
        if rdoc:
            notes.append(f'returns: {rdoc}')
        if notes:
            desc = (desc + '<br>' if desc else '') + '<br>'.join(notes)
        if not prose and not pdocs and not rdoc:
            undocumented.append(label)
        rows.append(f"| `{esc(label)}` | `{esc(params)}` | `{esc(f['ret'])}` | {esc(desc)} |")
    out = [f'# {libname}', '']
    if overview:
        out += [overview, '']
    out += ['| Function | Parameters | Returns | Description |',
            '|---|---|---|---|'] + rows + ['']
    if undocumented:
        out += [f'## Undocumented functions ({len(undocumented)})', '']
        out += [f'- {n}' for n in undocumented] + ['']
    if hidden:
        out += [f'_Hidden helpers ({len(hidden)}): '
                + ', '.join(f['name'] for f in hidden) + '_', '']
    return '\n'.join(out), len(public), len(undocumented), len(hidden)


def main(argv):
    args = argv[1:]
    if not args:
        print(__doc__)
        return 1
    paths, i = [], 0
    while i < len(args):
        if args[i] == '--all' and i + 1 < len(args):
            paths += sorted(glob.glob(os.path.join(args[i + 1], 'mocha-*.mch')))
            i += 2
        else:
            paths.append(args[i])
            i += 1
    os.makedirs('spec_gen', exist_ok=True)
    summary = ['| Library | Public | Undocumented | Hidden |', '|---|---|---|---|']
    for p in paths:
        name = os.path.splitext(os.path.basename(p))[0]
        overview, funcs = parse_file(p)
        md, npub, nundoc, nhid = render(name, overview, funcs)
        with open(os.path.join('spec_gen', name + '.md'), 'w', encoding='utf-8') as fh:
            fh.write(md)
        summary.append(f'| {name} | {npub} | {nundoc} | {nhid} |')
        print(f'{name}: {npub} public, {nundoc} undocumented, {nhid} hidden')
    with open(os.path.join('spec_gen', '_summary.md'), 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(summary) + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))