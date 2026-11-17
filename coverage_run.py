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
print(f"🟡 emitted but mismatched:     {n_mismatch}")
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
known, other = [], []
for f, name, items in mismatch_list:
    lost = all(LOSS_OURS.search(s) or LOSS_SRC.search(re.sub(r'"(?:\\.|[^"\\])*"', '""', sl)) for _, s, sl in items)
    (known if lost else other).append((f, name, items))

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