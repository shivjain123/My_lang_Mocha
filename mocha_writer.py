# mocha_writter.py  (run from corpus_current\)
import sys, os, re, glob
from mocha_emitter import (parse_module, parse_globals, classify_function, header, emit_straight,
                           infer_returns, owner_of, EmitError, mocha_type, FIELD_NAMES, FIELD_TYPES,
                           infer_collections, TAG_NAMES, GEP_FIELD_RE, SLOT_ANY_LOAD_RE, SLOT_STORE_GEN_RE, STORE_RE, LOAD_RE, BITCAST_RE)


LIB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib")
_DEF = re.compile(r'^define\b.*@([\w.$]+)\(')
_DEFG = re.compile(r'^@([A-Za-z_][\w.$]*) = (?!external)')
_DECL = re.compile(r'^declare\b.*@([\w.$]+)\(')
_DECLG = re.compile(r'^@([A-Za-z_][\w.$]*) = external')
_NATIVE = re.compile(r'\bfunction\s+(\w+)\s*\([^)]*\)[^;{]*?\bnative\s+(\w+)\s*;')
_IMP = re.compile(r'from\s+"mocha-(\w+)"\s+import')
_LIB = {}


def _load_libs():
    if _LIB:
        return
    index, deps = {}, {}
    for p in glob.glob(os.path.join(LIB_DIR, "mocha-*.ll")):
        lib = os.path.basename(p)[6:-3]
        for l in open(p, encoding="utf-8", errors="replace"):
            m = _DEF.match(l) or _DEFG.match(l)
            if m:
                index.setdefault(m.group(1), set()).add(lib)
    for p in glob.glob(os.path.join(LIB_DIR, "mocha-*.mch")):
        lib = os.path.basename(p)[6:-4]
        t = open(p, encoding="utf-8", errors="replace").read()
        for _, nat in _NATIVE.findall(t):
            index.setdefault(nat, set()).add(lib)
        d = set(_IMP.findall(t))
        for mm in re.finditer(r'^\s*//\s*mocha-lib-deps:\s*(.+)$', t, re.M):
            d |= {re.sub(r'^mocha-', '', x.strip()) for x in mm.group(1).split(",") if x.strip()}
        deps[lib] = d - {lib}
    _LIB["index"] = {k: next(iter(v)) for k, v in index.items() if len(v) == 1}
    _LIB["deps"] = deps


def _closure(lib, seen=None):
    seen = set() if seen is None else seen
    for d in _LIB["deps"].get(lib, ()):
        if d not in seen:
            seen.add(d)
            _closure(d, seen)
    return seen


def import_lines(text):
    _load_libs()
    pred, gl_ = set(), set()
    for l in text.splitlines():
        m = _DECL.match(l) or _DECLG.match(l)
        if m and m.group(1) in _LIB["index"]:
            pred.add(_LIB["index"][m.group(1)])
            if _DECLG.match(l):
                gl_.add(_LIB["index"][m.group(1)])
    libs_with_globals = set()
    for p in glob.glob(os.path.join(LIB_DIR, "mocha-*.ll")):
        if any(_DEFG.match(x) for x in open(p, encoding="utf-8", errors="replace")):
            libs_with_globals.add(os.path.basename(p)[6:-3])
    pred = {x for x in pred if x in gl_ or x not in libs_with_globals}    # a lib that defines globals leaves them as 'external' in every importer
    pred = {x for x in pred if not any(x in _closure(y) and y not in _closure(x) for y in pred if y != x)}
    return [f'from "mocha-{x}" import *;' for x in sorted(pred)] + ([""] if pred else [])


def fold(stmts):
    """A block whose header and statements all come from one source line is printed on one line."""
    out, i = [], 0
    while i < len(stmts):
        n, t = stmts[i]
        s = t.lstrip()
        if n is not None and s.endswith("{") and not s.startswith("}"):
            depth, j, ok = 0, i, True
            while j < len(stmts):
                nj, sj = stmts[j][0], stmts[j][1].lstrip()
                if sj.startswith("}") and not sj.endswith("{"):
                    depth -= 1
                elif sj.endswith("{") and not sj.startswith("}"):
                    depth += 1
                if nj is not None and nj != n:
                    ok = False
                if depth == 0 or not ok:
                    break
                j += 1
            if ok and depth == 0 and j > i:
                out.append((n, t + " " + " ".join(x[1].lstrip() for x in stmts[i + 1:j + 1])))
                i = j + 1
                continue
        out.append((n, t))
        i += 1
    return out


def body(fn, g, pad):
    lines = [pad + header(fn)]
    consts_, seen_c, last_empty = [], set(), None
    for l_ in fn.block_order:              # a const compiles to no code, but its line gets a marker followed at once by another marker
        pm_ = None
        for x_ in fn.blocks[l_].instrs:
            um_ = re.match(r'^call void @mocha_stack_update_line\(i32 (\d+)\)', x_.text)
            if um_:
                if pm_ is not None:
                    last_empty = int(pm_)
                pm_ = um_.group(1)
                continue
            pm_ = None
            cm_ = re.match(r'^%[\w.$]+ = (add i32 0|fadd double 0\.0), (\S+)\s*;\s*const (\w+)\s*$', x_.raw.strip())
            if not cm_ or cm_.group(3) in seen_c or cm_.group(3) in lib_consts():
                continue
            seen_c.add(cm_.group(3))
            if cm_.group(1) == "add i32 0":
                cty_, cval_ = "int", cm_.group(2)
            else:
                import struct
                v_ = cm_.group(2)
                cty_, cval_ = "float", repr(struct.unpack('>d', bytes.fromhex(v_[2:]))[0] if v_.startswith("0x") else float(v_))
            consts_.append((last_empty, f"const {cm_.group(3)}: {cty_} = {cval_};"))
    stmts_ = fold(emit_straight(fn, g))
    for cl_, ct_ in consts_:
        if cl_ is None:
            lines.append(pad + "    " + ct_)
            continue
        k_ = next((j for j, (nn_, _) in enumerate(stmts_) if nn_ is not None and nn_ > cl_), len(stmts_))
        ind_ = re.match(r'\s*', stmts_[k_][1]).group(0) if k_ < len(stmts_) else "" # type: ignore
        stmts_.insert(k_, (cl_, ind_ + ct_))
    prev = None
    for n, text in stmts_:
        t = text.lstrip()
        if (n is not None and n == prev and not t.startswith("}") and not t.endswith("{")
                and not lines[-1].rstrip().endswith("{")):
            lines[-1] += " " + t           # same source line: same output line
        else:
            lines.append(pad + "    " + text)
        prev = n                           # closers have no line, so they reset it
    lines.append(pad + "};")          # function closer needs its ;
    return lines

def lib_consts():
    """Names of every `const NAME` declared in lib\\mocha-*.mch: those come from an import, not from this file."""
    if "consts" not in _LIB:
        s = set()
        for p in glob.glob(os.path.join(LIB_DIR, "mocha-*.mch")):
            s |= set(re.findall(r'^\s*const\s+(\w+)\s*:', open(p, encoding="utf-8", errors="replace").read(), re.M))
        _LIB["consts"] = s
    return _LIB["consts"]

def native_lines(text, imports):
    """declares that are not in the runtime prelude, and whose lib was not imported: the file declared them itself."""
    _load_libs()
    from mocha_deparser import runtime_prelude
    pre = runtime_prelude()
    imp = {re.sub(r'^from "mocha-(\w+)".*', r'\1', x) for x in imports if x.startswith("from ")}
    tmap = {"i32": "int", "i64": "vast", "double": "float", "void": "null", "i8*": "null", "i8": "bool"}
    out = []
    for ret, name, args in re.findall(r'^declare (\S+) @([\w.$]+)\(([^)]*)\)', text, re.M):
        lib = _LIB["index"].get(name)
        if name in pre or lib is None or lib in imp or not re.search(r'call [^@\n]*@' + re.escape(name) + r'\(', text):
            continue
        ps = [a.strip() for a in args.split(",") if a.strip()]
        if ret not in tmap or any(a not in tmap for a in ps):
            continue
        out.append(f"function {name}({', '.join(f'p{k}: {tmap[a]}' for k, a in enumerate(ps))}) -> {tmap[ret]} native {name};")
    return out + ([""] if out else [])

def native_lines2(text, imports, g):
    """A declared non-runtime symbol that is called, and whose lib (if any) was not imported: the file declared it as native."""
    _load_libs()
    imp = {re.sub(r'^from "mocha-(\w+)".*', r'\1', x) for x in imports if x.startswith("from ")}
    for x_ in list(imp):                   # a lib's dependencies are loaded with it: their natives are not the file's own
        imp |= _closure(x_)
    tmap = {"i32": "int", "i64": "vast", "double": "float", "void": "null", "i8": "bool"}

    def strlike(tok):
        return re.search(re.escape(tok) + r' = call i8\* @mocha_str', text) is not None
    out = []
    for name in g.natives:
        ret = g.declares[name]
        lib = _LIB["index"].get(name)
        if lib in imp or name in lib_defined() or re.search(r'_release$|_drop$|^mocha_ext_|^rc_|^__mocha', name):
            continue
        calls = re.findall(r'(?:(%[\w.$]+) = )?call [^@\n]*@' + re.escape(name) + r'\(([^)]*)\)', text)
        dm = re.search(r'^declare \S+ @' + re.escape(name) + r'\(([^)]*)\)', text, re.M)
        if not calls or not dm:
            continue
        ps = [a.strip() for a in dm.group(1).split(",") if a.strip()]
        if (ret not in tmap and ret != "i8*") or any(a not in tmap and a != "i8*" for a in ps):
            continue
        strs = set()
        for _, args in calls:
            for k, a in enumerate(x.strip().split()[-1] for x in args.split(",") if x.strip()):
                if strlike(a):
                    strs.add(k)
        def flows_to_str(r):               # the result feeds a string call, directly or through the local it is stored in
            if not r:
                return False
            use = r'@mocha_(?:print_str|str_\w+)\(.*i8\* '
            if re.search(use + re.escape(r) + r'\b', text):
                return True
            for sl in re.findall(r'store i8\* ' + re.escape(r) + r', i8\*\* (%[\w.$]+)', text):
                for lv in re.findall(r'(%[\w.$]+) = load i8\*, i8\*\* ' + re.escape(sl) + r'\b', text):
                    if re.search(use + re.escape(lv) + r'\b', text):
                        return True
            return False
        rstr = any(flows_to_str(r) for r, _ in calls)
        pt = [("str" if k in strs else "null") if a == "i8*" else tmap[a] for k, a in enumerate(ps)]
        import mocha_emitter as _me
        rt = _me.NATIVE_RET_MOD.get(name, "str" if rstr else "null") if ret == "i8*" else tmap[ret]
        out.append(f"function {name}({', '.join(f'p{k}: {t}' for k, t in enumerate(pt))}) -> {rt} native {name};")
    return sorted(out) + ([""] if out else [])

def lib_defined():
    """Every function a lib .ll defines, however many libs share the name: those are library code, never a user native."""
    if "defined" not in _LIB:
        s = set()
        for p in glob.glob(os.path.join(LIB_DIR, "mocha-*.ll")):
            for l in open(p, encoding="utf-8", errors="replace"):
                m = _DEF.match(l)
                if m:
                    s.add(m.group(1))
        _LIB["defined"] = s
    return _LIB["defined"]


def ext_receiver(name, class_names):
    """mocha_ext_<recv>_<method> -> the type after `extend`."""
    rest = name[len("mocha_ext_"):]
    for pre, ty in (("float_arr_", "float[]"), ("int_arr_", "int[]"), ("str_arr_", "str[]"),
                    ("float_", "float"), ("int_", "int"), ("str_", "str"), ("bool_", "bool")):
        if rest.startswith(pre):
            return ty
    return max((c for c in class_names if rest.startswith(c + "_")), key=len, default=rest.split("_")[0])

KIND_DEFAULT = {"%MochaArray*": "float[]", "%MochaArray2D*": "float[][]", "%MochaSet*": "set<int>"}


def field_evidence(funcs):
    """(struct, field index) -> collection type, from typed locals copied to or from that field."""
    ev = {}

    def note(key, ty):
        if not ty:
            return
        if key not in ev:
            ev[key] = ty
        elif ev[key] != ty:
            ev[key] = None                 # two different answers: don't trust either

    for fn in funcs.values():
        instrs = [i for l in fn.block_order for i in fn.blocks[l].instrs]
        defs = {i.result: i for i in instrs if i.result}
        gep = {}
        for i in instrs:
            gm = GEP_FIELD_RE.match(i.text) if i.op == "getelementptr" else None
            if gm and i.result:
                gep[i.result] = (gm.group(1), gm.group(3))
        if not gep:
            continue
        colls = infer_collections(fn)
        for i in instrs:
            if i.op != "store":
                continue
            sm = STORE_RE.match(i.text)               # a local <- a load of the field
            if sm and sm.group(4) in colls:
                ld = defs.get(sm.group(2))
                lm = SLOT_ANY_LOAD_RE.match(ld.text) if ld is not None and ld.op == "load" else None
                if lm and lm.group(1) in gep:
                    note(gep[lm.group(1)], colls[sm.group(4)][0])
            gm2 = SLOT_STORE_GEN_RE.match(i.text)     # the field <- a load of a local
            if gm2 and gm2.group(2) in gep:
                ld = defs.get(gm2.group(1))
                lm = LOAD_RE.match(ld.text) if ld is not None and ld.op == "load" else None
                if lm and lm.group(3) in colls:
                    note(gep[gm2.group(2)], colls[lm.group(3)][0])
    for fn in funcs.values():              # Cls_drop: release_objs(field, @Elem_release) names the element class of a 2D field
        if not fn.name.endswith("_drop"):
            continue
        instrs = [i for l in fn.block_order for i in fn.blocks[l].instrs]
        defs = {i.result: i for i in instrs if i.result}
        for i in instrs:
            m = re.match(r'^call void @mocha_array2d_release_objs\(%MochaArray2D\* (%[\w.$]+), void \(i8\*\)\* bitcast \(void \(%struct\.\w+\*\)\* @(\w+)_release to void \(i8\*\)\*\)', i.text) if i.op == "call" else None
            ld = defs.get(m.group(1)) if m else None
            lm = SLOT_ANY_LOAD_RE.match(ld.text) if ld is not None and ld.op == "load" else None
            gd = defs.get(lm.group(1)) if lm else None
            gm = GEP_FIELD_RE.match(gd.text) if gd is not None and gd.op == "getelementptr" else None
            if gm:
                assert m is not None
                ev[(gm.group(1), gm.group(3))] = m.group(2) + "[][]"
            m1 = re.match(r'^call void @mocha_array_release\(%MochaArray\* (%[\w.$]+), i32 1\)', i.text) if i.op == "call" else None
            ld1 = defs.get(m1.group(1)) if m1 else None
            lm1 = SLOT_ANY_LOAD_RE.match(ld1.text) if ld1 is not None and ld1.op == "load" else None
            gd1 = defs.get(lm1.group(1)) if lm1 else None
            gm1 = GEP_FIELD_RE.match(gd1.text) if gd1 is not None and gd1.op == "getelementptr" else None
            if gm1:
                ev[(gm1.group(1), gm1.group(3))] = "str[]"      # release flag 1 in Cls_drop: a string array
    for fn in funcs.values():              # mocha_set_<op>_str on a loaded field: a string set
        instrs = [i for l in fn.block_order for i in fn.blocks[l].instrs]
        defs = {i.result: i for i in instrs if i.result}
        for i in instrs:
            ms = re.match(r'^call [^@]*@mocha_set_\w*_str\(%MochaSet\* (%[\w.$]+)', i.text) if i.op == "call" else None
            ld = defs.get(ms.group(1)) if ms else None
            lm = SLOT_ANY_LOAD_RE.match(ld.text) if ld is not None and ld.op == "load" else None
            gd = defs.get(lm.group(1)) if lm else None
            gm = GEP_FIELD_RE.match(gd.text) if gd is not None and gd.op == "getelementptr" else None
            if gm:
                ev[(gm.group(1), gm.group(3))] = "set<str>"
    for fn in funcs.values():              # a field loaded and compared with a Tag__MEMBER global: a field of that tag type
        instrs = [i for l in fn.block_order for i in fn.blocks[l].instrs]
        defs = {i.result: i for i in instrs if i.result}
        for i in instrs:
            cm = re.match(r'^icmp (?:eq|ne) i32 (%[\w.$]+), (%[\w.$]+)', i.text) if i.op == "icmp" else None
            if not cm:
                continue
            for a_, b_ in ((cm.group(1), cm.group(2)), (cm.group(2), cm.group(1))):
                da, db = defs.get(a_), defs.get(b_)
                tm = re.match(r'^load i32, i32\* @(\w+?)__\w+', db.text) if db is not None and db.op == "load" else None
                lm = SLOT_ANY_LOAD_RE.match(da.text) if da is not None and da.op == "load" else None
                gd = defs.get(lm.group(1)) if lm else None
                gm = GEP_FIELD_RE.match(gd.text) if gd is not None and gd.op == "getelementptr" else None
                if tm and gm and tm.group(1) in TAG_NAMES:
                    ev[(gm.group(1), gm.group(3))] = tm.group(1)
    return ev

def parent_of(cls, funcs, g):
    """-> (parent class, number of inherited fields) from the %self stubs the compiler generates for inherited methods, or (None, 0)."""
    cands = set()
    for fn in funcs.values():
        if not fn.name.startswith(cls + "_") or not fn.params or fn.params[0][1] != "%self":
            continue
        if classify_function(fn)[0] not in ("ctor", "method"):
            continue
        meth = fn.name[len(cls) + 1:]
        for l in fn.block_order:
            for i in fn.blocks[l].instrs:
                m = re.search(r'@(\w+)_' + re.escape(meth) + r'\(', i.text) if i.op == "call" else None
                if m and m.group(1) != cls and f"{m.group(1)}_release" in funcs and g.types.get("struct." + m.group(1)):
                    cands.add(m.group(1))
    ct, best = g.types.get("struct." + cls) or [], (None, 0)
    for p in cands:
        pt = g.types["struct." + p]
        if ct[:len(pt)] == pt and len(pt) > best[1]:
            best = (p, len(pt))
    return best

def stub_parents(cls, funcs, g):
    """Classes that Cls's compiler-generated %self stubs call into."""
    cands = set()
    for fn in funcs.values():
        if not fn.name.startswith(cls + "_") or not fn.params or fn.params[0][1] != "%self":
            continue
        if classify_function(fn)[0] not in ("ctor", "method"):
            continue
        meth = fn.name[len(cls) + 1:]
        for l in fn.block_order:
            for i in fn.blocks[l].instrs:
                m = re.search(r'@(\w+)_' + re.escape(meth) + r'\(', i.text) if i.op == "call" else None
                if m and m.group(1) != cls and f"{m.group(1)}_release" in funcs and g.types.get("struct." + m.group(1)):
                    cands.add(m.group(1))
    return cands

def parents_of(cls, funcs, g):
    """-> (parents in extends order, number of inherited fields): each parent's fields (type and name) sit in order at the start of the child's struct."""
    ct = g.types.get("struct." + cls) or []
    if not ct:
        return [], 0

    def names(c, n):
        return [FIELD_NAMES.get((c, str(k))) for k in range(n)]
    cnames = names(cls, len(ct))
    cands = {}
    for fn in funcs.values():
        m = re.match(r'^(\w+)_release$', fn.name)
        if m and m.group(1) != cls and g.types.get("struct." + m.group(1)):
            cands[m.group(1)] = g.types["struct." + m.group(1)]
    cands = {p: t for p, t in cands.items() if parent_of(p, funcs, g)[0] != cls}      # never take a class that itself extends this one
    pos, parents = 0, []
    while pos < len(ct):
        best = None
        for p, pt in cands.items():
            pn = names(p, len(pt))
            seg = cnames[pos:pos + len(pt)]
            if None in pn or None in seg or len(seg) != len(pt):
                continue
            if ct[pos:pos + len(pt)] == pt and seg == pn and (best is None or len(pt) > len(cands[best])):
                best = p
        if best is None:
            break
        parents.append(best)
        pos += len(cands[best])
    if parents:
        return parents, pos
    sp = stub_parents(cls, funcs, g)       # no field names to match: the stub-called classes that fit the struct by type, in definition order
    pos2, out2 = 0, []
    for key_ in g.types:
        p_ = key_[len("struct."):]
        pt_ = g.types[key_]
        if p_ in sp and p_ != cls and pt_ and ct[pos2:pos2 + len(pt_)] == pt_:
            out2.append(p_)
            pos2 += len(pt_)
    return out2, pos2


def weak_fields(cls, funcs):
    """Field indexes (as strings) that Cls_drop releases with rc_weak_release: those are the weak fields."""
    fn = funcs.get(f"{cls}_drop")
    if fn is None:
        return set()
    instrs = [i for l in fn.block_order for i in fn.blocks[l].instrs]
    defs = {i.result: i for i in instrs if i.result}
    out = set()
    for i in instrs:
        m = re.match(r'^call void @rc_weak_release\(i8\* (%[\w.$]+)\)', i.text) if i.op == "call" else None
        if not m:
            continue
        bd = defs.get(m.group(1))
        bm = BITCAST_RE.match(bd.text) if bd is not None else None
        ld = defs.get(bm.group(2)) if bm else None
        lm = SLOT_ANY_LOAD_RE.match(ld.text) if ld is not None and ld.op == "load" else None
        gd = defs.get(lm.group(1)) if lm else None
        gm = GEP_FIELD_RE.match(gd.text) if gd is not None and gd.op == "getelementptr" else None
        if gm and gm.group(1) == cls:
            out.add(gm.group(3))
    return out


def field_lines(cls, g, ev, weak=(), start=0, borrow=None):
    borrow = borrow or {}
    out = []
    for k, llvm in enumerate(g.types.get("struct." + cls, [])):
        if k < start:
            continue
        if len(g.types.get("struct." + cls, [])) == 1 and (cls, "0") not in FIELD_NAMES and (cls, "0") not in borrow and llvm.strip() == "i32":
            continue
        name = FIELD_NAMES.get((cls, str(k))) or borrow.get((cls, str(k))) or f"field{k}"
        ty = FIELD_TYPES.get((cls, str(k)))
        if ty == "float[][]" and (ev.get((cls, str(k))) or "").endswith("[][]") and ev[(cls, str(k))] != "float[][]":
            ty = ev[(cls, str(k))]         # Cls_drop names the element class; the creation-arg guess said float
        if ev.get((cls, str(k))) in TAG_NAMES:
            ty = ev[(cls, str(k))]         # compared against Tag__MEMBER globals: a tag-typed field
        if ty is None:
            try:
                ty = mocha_type(llvm)
            except EmitError:
                ty = ev.get((cls, str(k))) or KIND_DEFAULT.get(llvm.strip(), "?")
        out.append(f"    {'weak ' if str(k) in weak else ''}var {name}: {ty};")
    return out


def write_module(text):
    funcs, g = parse_module(text), parse_globals(text)
    infer_returns(funcs, g)
    kinds = {n: classify_function(f)[0] for n, f in funcs.items()}
    class_names = [k[len("struct."):] for k in g.types
                   if not k[len("struct."):].startswith("Mocha") and g.types[k] is not None
                   and f"{k[len('struct.'):]}_release" in funcs]

    def shared_owner(fn):                  # a plain function named Cls_name that belongs to a defined class is a shared method
        if kinds[fn.name] != "plain":
            return None
        return max((c for c in class_names if fn.name.startswith(c + "_")), key=len, default=None)
    out = import_lines(text)
    out += native_lines2(text, out, g)
    blocks = {}                            # ("c", class) / ("f", function) -> its printed lines; put in IR order at the end
    ev = field_evidence(funcs)
    borrow = {}                            # a parent's field named only through a child class that inherits it
    for key_ in g.types:
        c_ = key_[len("struct."):]
        if c_.startswith("Mocha") or g.types[key_] is None or f"{c_}_release" not in funcs:
            continue
        ps_, nin_ = parents_of(c_, funcs, g)
        if len(ps_) == 1:
            for k_ in range(nin_):
                if (c_, str(k_)) in FIELD_NAMES:
                    borrow.setdefault((ps_[0], str(k_)), FIELD_NAMES[(c_, str(k_))])
    for key in g.types:
        cls = key[len("struct."):]
        if cls.startswith("Mocha") or g.types[key] is None or f"{cls}_release" not in funcs:
            continue                  # runtime, opaque and library classes are not defined in this file
        mark_ = len(out)
        pars, nin = parents_of(cls, funcs, g)
        out.append(f"class {cls} extends {', '.join(pars)} {{" if pars else f"class {cls} {{")
        out += field_lines(cls, g, ev, weak_fields(cls, funcs), nin, borrow)
        for fn in funcs.values():
            if kinds[fn.name] in ("ctor", "method") and owner_of(fn) == cls \
                    and not (fn.params and fn.params[0][1] == "%self"):
                out += body(fn, g, "    ")
            elif shared_owner(fn) == cls:
                blk_ = body(fn, g, "    ")
                blk_[0] = re.sub(r'function ' + re.escape(cls) + r'_(\w+)\(', r'shared function \1(', blk_[0], count=1)
                out += blk_
        out += ["};", ""]
        blocks[("c", cls)] = out[mark_:]
        del out[mark_:]
    for fn in funcs.values():
        if fn.name == "mocha_main" and len(body(fn, g, "")) <= 2:
            continue                       # the compiler always adds an empty @mocha_main; it is not source
        if kinds[fn.name] in ("plain", "entry") and not shared_owner(fn):
            blocks[("f", fn.name)] = body(fn, g, "") + [""]
            pass
    strs_ = {m.group(1): m.group(2) for m in re.finditer(r'^@(\.str\d+) = [^\n]*? c"((?:[^"\\]|\\.)*)"', text, re.M)}
    for fn in funcs.values():              # Tag__name: its tag_caseN blocks return the member names in declaration order
        if not fn.name.endswith("__name"):
            continue
        mem_ = []
        for l_ in fn.block_order:
            if l_.startswith("tag_case"):
                for x_ in fn.blocks[l_].instrs:
                    sm_ = re.search(r'@(\.str\d+),', x_.text)
                    if sm_:
                        mem_.append(strs_[sm_.group(1)].replace("\\00", ""))
                        break
        if mem_:
            blocks[("t", fn.name[:-6])] = [f"tag {fn.name[:-6]} {{"] + [f"    {m_}," for m_ in mem_] + ["};", ""]
    ext_ = {}
    for fn in funcs.values():
        if kinds[fn.name] == "ext_method":
            ext_.setdefault(ext_receiver(fn.name, class_names), []).extend(body(fn, g, "    "))
    for recv_, ls_ in ext_.items():
        blocks[("e", recv_)] = [f"extend {recv_} {{"] + ls_ + ["};", ""]
    cls_names = [k[1] for k in blocks if k[0] == "c"]
    order, seen = [], set()
    for fn in funcs.values():              # IR order is source order: a class sits where its first function is
        owner_ = max((c for c in cls_names if fn.name.startswith(c + "_")), key=len, default=None)
        key_ = ("t", fn.name[:-6]) if fn.name.endswith("__name") and ("t", fn.name[:-6]) in blocks else ("e", ext_receiver(fn.name, class_names)) if kinds[fn.name] == "ext_method" else ("c", owner_) if owner_ else ("f", fn.name)
        if key_ in blocks and key_ not in seen:
            seen.add(key_)
            order.append(key_)
    order += [k for k in blocks if k not in seen]      # anything the walk missed goes at the end
    for key_ in order:
        out += blocks[key_]
    return "\n".join(out)


if __name__ == "__main__":
    print(write_module(open(sys.argv[1] + ".ll", encoding="utf-8").read()))