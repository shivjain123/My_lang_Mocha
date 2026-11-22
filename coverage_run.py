import sys, os, re, glob, collections, traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mocha_emitter import (NATIVE_ALIAS, parse_module, parse_globals, classify_function, header, emit_straight,
                           line_matches, header_matches, infer_returns, EmitError, owner_of)

SYNTH = {"release", "drop_empty", "drop_generated", "enum_name", "drop_user", "lambda"}   # compiler-generated, no source lines


def reason_of(msg):
    msg = re.sub(r'^[^:]+: ', '', msg, count=1)          # drop the function name prefix
    if "LLVM type" in msg:
        return msg[:130]
    msg = re.sub(r'0x[0-9a-fA-F]+', '0x?', msg)
    msg = re.sub(r'%[\w.\-$]+', '%?', msg)               # temp names
    if 'no rule yet' not in msg:
        msg = re.sub(r'@[\w.\-$]+', '@?', msg)
    msg = re.sub(r'\b\d+\b', 'N', msg)
    return msg[:130]


files = sorted(glob.glob("*.ll"))
if not files:
    print("❌ No .ll files here. Run me from corpus_current\\")
    sys.exit(1)

kind_total = collections.Counter()
kind_ok = collections.Counter()
reasons = collections.Counter()
examples = {}
hdr_count = collections.Counter()
n_funcs = n_ok = n_mismatch = n_synth = 0
stmts_total = stmts_good = 0
no_source, bad_files, mismatch_list = [], [], []
stale = []

for f in files:
    stem = f[:-3]
    mch0 = os.path.join("..", stem + ".mch")
    if os.path.exists(mch0) and os.path.getmtime(mch0) > os.path.getmtime(f):
        stale.append(stem)                 # the source changed after this .ll was built
        continue
    try:
        text = open(f, encoding="utf-8").read()
        funcs, g = parse_module(text), parse_globals(text)
        infer_returns(funcs, g)
    except Exception as e:
        bad_files.append((f, f"{type(e).__name__}: {e}"))
        continue

    mch = os.path.join("..", stem + ".mch")
    if os.path.exists(mch):
        src = open(mch, encoding="utf-8", errors="replace", newline="").read().split("\n")
    else:
        src = None
        no_source.append(stem)
    if src:                               # natives declared in the file itself: function name(...) -> T native mocha_wrap_x;
        for nm_, nat_ in re.findall(r'^\s*(?:local\s+)?function\s+(\w+)\s*\([^)]*\)\s*(?:->\s*[\w\[\]<>, ]+)?\s*native\s+(\w+)\s*;', "\n".join(src), re.M):
            NATIVE_ALIAS.setdefault(nat_, nm_)
    aliases = set(re.findall(r'^\s*(?:from\b[^;]*)?import\b[^;]*\bas\s+(\w+)\s*;', "\n".join(src), re.M)) if src else set()
    if aliases:                           # 'import "mocha-SymCha" as Sym;' -> Sym.f(x) is just f(x) in the IR
        arx = re.compile(r'\b(?:' + '|'.join(map(re.escape, aliases)) + r')\.(?=\w)')
        src = [arx.sub('', l) for l in src] # type: ignore

    if src and stem == "mocha_ffi_tests":      # frozen old snapshot: it still uses the older lua names
            OLD_LUA = {"lua_new": "lua_open", "lua_dostring": "lua_run", "lua_getnumber": "lua_get_number", "lua_getstring": "lua_get_string"}
            lrx = re.compile(r'\b(' + '|'.join(OLD_LUA) + r')\b')
            src = [lrx.sub(lambda m: OLD_LUA[m.group(1)], l) for l in src]
    for fn in funcs.values():
        if fn.name == "main":
            continue
        try:
            kind = classify_function(fn)[0]
        except Exception:
            kind = "?"
        if kind in SYNTH or (kind in ("ctor", "method") and fn.params and fn.params[0][1] == "%self"):
            # compiler-generated: release/drop, default constructors, inherited-method stubs:
            n_synth += 1
            continue
        n_funcs += 1
        kind_total[kind] += 1
        try:
            head = header(fn)
            stmts = emit_straight(fn, g)
        except EmitError as e:
            r = reason_of(str(e))
            reasons[r] += 1
            examples.setdefault(r, f"{f} :: {fn.name}")
            continue
        except Exception as e:
            r = f"CRASH {type(e).__name__}: {reason_of(str(e))}"
            reasons[r] += 1
            examples.setdefault(r, f"{f} :: {fn.name}  ({traceback.format_exc().strip().splitlines()[-2].strip()})")
            continue

        if src is None:
            kind_ok[kind] += 1
            n_ok += 1
            continue

        by_line = collections.OrderedDict()
        for n, s in stmts:
            if s.lstrip().startswith("}"):      # structural lines have no source line
                continue
            by_line.setdefault(n, []).append(s)
        bad = [(n, "".join(ss)) for n, ss in by_line.items()
               if not (n is not None and 1 <= n <= len(src)
                       and line_matches(src, n, "".join(ss)))]
        stmts_total += len(by_line)
        stmts_good += len(by_line) - len(bad)
        hok, hline, _ = header_matches(src, head, owner_of(fn))
        hdr_count[hok] += 1
        if hok is False:
            bad.insert(0, (hline, head))
        if bad:
            n_mismatch += 1
            items = [(n, s, src[n - 1].strip() if n is not None and 1 <= n <= len(src) else "<no line>")
                     for n, s in bad]
            mismatch_list.append((f, fn.name, items))
        else:
            n_ok += 1
            kind_ok[kind] += 1

print(f"files: {len(files)}   functions (excluding main): {n_funcs}")
print(f"✅ emitted + round-trip clean: {n_ok}")
# the mismatch count is printed below, once the known losses are set aside
print(f"❌ unsupported / crash:        {n_funcs - n_ok - n_mismatch}")
if stmts_total:
    print(f"statements: {stmts_good}/{stmts_total} match their source line")
print(f"headers: {hdr_count[True]} match, {hdr_count[False]} differ, "
      f"{hdr_count[None]} have no 'function NAME(' line in the source")

print("\nBy function kind (ok / total):")
for k, n in kind_total.most_common():
    print(f"  {k:15s} {kind_ok[k]:4d} / {n}")

print("\nTop failure reasons:")
for r, n in reasons.most_common(20):
    print(f"  {n:4d} × {r}\n         e.g. {examples[r]}")

LOSS_OURS = re.compile(r'\bink_\w+|\bfield\d+')      # library alias, unnamed class field
LOSS_SRC = re.compile(r'(?<![\w."])[A-Z][A-Z0-9_]*\b|0\.00000\d')   # folded constant names (PI, GM_SUN...), floats too small for the IR
def norm_loss(s):
    """Our line with the two accepted losses undone: tests that predate the unified lib say plain ptr_of, and an unused native result leaves no trace of str."""
    s = re.sub(r'\bptr_of_(?:float|int|vast|bool)\(', 'ptr_of(', s.strip())
    return re.sub(r'^var (\w+): null = ', r'var \1: str = ', s)

_dfn = {}


def default_fns(ll_name):
    """Functions the source declares with default parameters ('function add(a: int, b: int = 10)'): the IR only has the values the compiler filled in."""
    if ll_name not in _dfn:
        try:
            txt = open(os.path.join("..", ll_name[:-3] + ".mch"), encoding="utf-8", errors="replace").read()
        except OSError:
            txt = ""
        _dfn[ll_name] = set(re.findall(r'\bfunction\s+(\w+)\s*\([^)]*=[^)]*\)', txt))
    return _dfn[ll_name]


def norm_defaults(s, names):
    """A line with default parameters set aside: a header loses its '= value', and a call to one of those functions becomes name(...)."""
    rx = re.compile(r'\bfunction\s+\w+\s*\(|\b(?:' + '|'.join(map(re.escape, sorted(names))) + r')\(')
    out, i = "", 0
    while True:
        m = rx.search(s, i)
        if not m:
            return re.sub(r'\s+', '', out + s[i:])
        d, j = 1, m.end()
        while j < len(s) and d:
            d += (s[j] == '(') - (s[j] == ')')
            j += 1
        if m.group(0).startswith("function"):
            parts, d, cur = [], 0, ""
            for ch in s[m.end():j - 1]:
                d += (ch in "([{") - (ch in ")]}")
                if ch == "," and d == 0:
                    parts.append(cur)
                    cur = ""
                else:
                    cur += ch
            parts.append(cur)
            out += s[i:m.end()] + ",".join(p.split("=")[0] for p in parts) + ")"
        else:
            out += s[i:m.start()] + m.group(0) + "...)"
        i = j


def default_loss(f, s, sl):
    names = default_fns(f)
    return bool(names) and any(re.search(r'\b' + re.escape(n) + r'\b', sl) for n in names) \
        and norm_defaults(s, names) in norm_defaults(sl, names)


def norm_named(s):
    """Call arguments with names stripped and put in sorted order: the IR only has the positional order, and a source may name or reorder them (Rbm(hidden_size=3, visible_size=5))."""
    rx = re.compile(r'\b(?!print\b)(\w+)\(')
    out, i = "", 0
    while True:
        m = rx.search(s, i)
        if not m:
            return re.sub(r'\s+', '', out + s[i:])
        d, j = 1, m.end()
        while j < len(s) and d:
            d += (s[j] == '(') - (s[j] == ')')
            j += 1
        args, d, cur = [], 0, ""
        for ch in s[m.end():j - 1]:
            d += (ch in "([{") - (ch in ")]}")
            if ch == "," and d == 0:
                args.append(cur)
                cur = ""
            else:
                cur += ch
        args.append(cur)
        args = sorted(re.sub(r'^\s*[A-Za-z_]\w*\s*=(?!=)\s*', '', a).strip() for a in args)
        out += s[i:m.end()] + ",".join(args) + ")"
        i = j


def named_loss(s, sl):
    return bool(re.search(r'[(,]\s*(?!newLine\b)[A-Za-z_]\w*\s*=(?!=)', sl)) and norm_named(s) == norm_named(sl)


known, other = [], []
for f, name, items in mismatch_list:
    lost = all(LOSS_OURS.search(s) or LOSS_SRC.search(re.sub(r'"(?:\\.|[^"\\])*"', '""', sl)) or norm_loss(s) == sl.strip() or default_loss(f, s, sl) or named_loss(s, sl) for _, s, sl in items)
    (known if lost else other).append((f, name, items))
print(f"\n🟡 emitted but mismatched:     {len(other)}" + (f"   (+{len(known)} known losses, listed below)" if known else ""))

if other:
    print("\nMismatches to look at (up to 3 differing lines each):")
    for f, name, items in other:
        print(f"  {f} :: {name}   ({len(items)} differing)")
        for n, s, sl in items[:3]:
            print(f"      line {n}\n        ours:   {s[:140]}\n        source: {sl[:140]}")
if known:
    print(f"\n{len(known)} functions differ only by known losses (aliases, constant names, tiny floats); first difference of each:")
    for f, name, items in known:
        n, s, sl = items[0]
        print(f"  {f} :: {name}  ours: {s[:90]}  |  source: {sl[:90]}")

print(f"\n(skipped {n_synth} compiler-generated functions: release/drop_*)")
if no_source:
    print(f"⚠️  {len(no_source)} files have no ..\\<name>.mch (counted as ok if emitted, not verified)")
if bad_files:
    print(f"⚠️  {len(bad_files)} files failed to load:")
    for f, e in bad_files[:5]:
        print(f"  {f}: {e}")
if stale:
    print(f"⚠️  {len(stale)} files skipped, the .mch is newer than the .ll (recompile): {', '.join(stale[:8])}")