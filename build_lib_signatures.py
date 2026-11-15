import sys, os, re, glob, json, collections
HERE = os.path.dirname(os.path.abspath(__file__))

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mocha_emitter import (parse_module, classify_function, ALLOCA_RE, STORE_RE, CALL_RE,
                           LINE_RE, var_name)

SYNTH = {"release", "drop_empty", "drop_generated"}
AMBIG = {"i32", "%MochaArray*", "%MochaArray2D*", "%MochaSet*", "%MochaTuple*"}
BASIC = {"int", "float", "str", "bool", "vast", "null"}


def blank(text):
    """Blank out strings and comments but keep every offset the same."""
    out, i, n = list(text), 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                if text[j] == '\\':
                    j += 1
                j += 1
            for k in range(i + 1, min(j, n)):
                if text[k] != '\n':
                    out[k] = ' '
            i = j + 1
        elif text.startswith('//', i) or text.startswith('~~', i):
            j = text.find('\n', i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = ' '
            i = j
        elif text.startswith('/*', i):
            j = text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, min(j, n)):
                if text[k] != '\n':
                    out[k] = ' '
            i = j
        else:
            i += 1
    return ''.join(out)


def scan_signatures(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    clean = blank(text)
    spans = []
    for m in re.finditer(r'\bclass\s+(\w+)[^{;]*\{', clean):
        depth, j = 1, m.end()
        while j < len(clean) and depth:
            depth += (clean[j] == '{') - (clean[j] == '}')
            j += 1
        spans.append((m.start(), j, m.group(1)))
    found = []
    for m in re.finditer(r'\bfunction\s+(\w+)\s*\(', clean):
        depth, j = 1, m.end()
        while j < len(clean) and depth:
            depth += (clean[j] == '(') - (clean[j] == ')')
            j += 1
        rm = re.match(r'\s*->\s*([^{;]+?)\s*\{', clean[j:j + 300])
        if not rm:
            continue
        owners = [s for s in spans if s[0] < m.start() < s[1]]
        owner = min(owners, key=lambda s: s[1] - s[0])[2] if owners else None
        name = f"{owner}_{m.group(1)}" if owner else m.group(1)
        found.append((name, re.sub(r'\s+', '', rm.group(1))))
    return found


# ---- 1. build the table from lib\*.mch --------------------------------------
sigs = collections.defaultdict(lambda: collections.defaultdict(set))   # name -> type -> files
libs = sorted(glob.glob(os.path.join(HERE, "lib", "*.mch")))
if not libs:
    print("❌ no ..\\lib\\*.mch files found")
    sys.exit(1)
for p in libs:
    for name, ret in scan_signatures(p):
        sigs[name][ret].add(os.path.basename(p))

conflicts = {n: t for n, t in sigs.items() if len(t) > 1}
table = {n: next(iter(t)) for n, t in sigs.items() if len(t) == 1}
print(f"{len(libs)} lib files, {len(sigs)} named functions, {len(table)} usable, "
      f"{len(conflicts)} with conflicting return types")
for n, t in list(conflicts.items())[:10]:
    print(f"   conflict {n}: " + " | ".join(f"{ty} ({', '.join(sorted(fs))})" for ty, fs in t.items()))
with open(os.path.join(HERE, "lib_sigs.json"), "w", encoding="utf-8") as fh:
    json.dump(table, fh, indent=1, sort_keys=True)
print("📄 table written to ..\\lib_sigs.json")
if "--no-validate" in sys.argv:        # the shipped build stops here; the rest checks the table against the test corpus
    sys.exit(0)


# ---- 2. validate against what the user declared on the 'var' lines ----------
def decl_re(name):
    return re.compile(r'\bvar\s+' + re.escape(name) + r'\b\s*(?::\s*([^=;]+?))?\s*(?:=|;)')


agree = collections.Counter()
bad, missing, ex = [], collections.Counter(), {}
for f in sorted(glob.glob("*.ll")):
    mch = os.path.join("..", f[:-3] + ".mch")
    if not os.path.exists(mch):
        continue
    src = open(mch, encoding="utf-8", errors="replace").read().splitlines()
    try:
        funcs = parse_module(open(f, encoding="utf-8").read())
    except Exception as e:
        print(f"⚠️  {f}: {type(e).__name__}: {e}")
        continue
    for fn in funcs.values():
        if fn.name == "main":
            continue
        try:
            if classify_function(fn)[0] in SYNTH:
                continue
        except Exception:
            pass
        instrs = [i for l in fn.block_order for i in fn.blocks[l].instrs]
        defs = {i.result: i for i in instrs if i.result}
        lines = [int(m.group(1)) for i in instrs for m in [LINE_RE.search(i.raw)] if m]
        lo, hi = (min(lines), max(lines)) if lines else (1, len(src))
        pnames = {n.lstrip('%') for _, n in fn.params}
        ptypes, done = {}, set()
        for i in instrs:
            if i.op == "alloca" and i.result and i.result.endswith(".ptr"):
                am = ALLOCA_RE.match(i.text)
                if am:
                    ptypes[i.result[1:-4]] = am.group(1).strip()
            if i.op != "store":
                continue
            sm = STORE_RE.match(i.text)
            if not sm or sm.group(2) == "null":
                continue
            ptr = sm.group(4)
            if ptr in done or ptypes.get(ptr) not in AMBIG or var_name(ptr) in pnames:
                continue
            d = defs.get(sm.group(2))
            m = CALL_RE.match(d.text) if d is not None and d.op == "call" else None
            if not m:
                continue
            done.add(ptr)
            callee = m.group(2)
            if callee.startswith(("mocha_", "rc_")) or callee in funcs:
                continue                      # builtins / same-file functions are handled elsewhere
            rx, decl = decl_re(var_name(ptr)), None
            for k in range(lo - 1, min(hi, len(src))):
                mm = rx.search(src[k])
                if mm:
                    decl = re.sub(r'\s+', '', mm.group(1) or "")
                    break
            if not decl:
                continue
            where = f"{f} :: {fn.name} {var_name(ptr)} = {callee}(...)  declared {decl}"
            if callee in conflicts:
                missing[("conflicting lib signatures", callee)] += 1
            elif callee not in table:
                missing[("not in lib table", callee)] += 1
                ex.setdefault(("not in lib table", callee), where)
            elif re.sub(r'\s+', '', table[callee]) == decl:
                agree["agree"] += 1
            else:
                agree["DISAGREE"] += 1
                bad.append(f"{where}   table says {table[callee]}")

print(f"\nvalidation: {dict(agree)}")
print(f"DISAGREEMENTS: {len(bad)}")
for b in bad[:25]:
    print("  ", b)
print(f"\nnot resolved ({sum(missing.values())}):")
for (why, callee), n in missing.most_common(20):
    print(f"  {n:3d} × {callee:38s} {why}   {ex.get((why, callee), '')[:70]}")