import os, re, sys, struct, collections, json
from mocha_deparser import parse_module, parse_globals, split_top_level, PRELUDE_TYPES
from mocha_classifier import classify_function, find_loops, find_ifs

LINE_RE = re.compile(r'@mocha_stack_update_line\(i32 (\d+)\)')
CALL_RE = re.compile(r'^(?:tail |musttail |notail )?call\s+(.+?)\s+@([\w.$]+)\((.*)\)\s*$')
LIT_INT_RE = re.compile(r'^add (i\d+) 0, (-?\d+)$')
LIT_FLT_RE = re.compile(r'^fadd double 0\.0, (\S+)$')
GEP_STR_RE = re.compile(
    r'^getelementptr \[\d+ x i8\], (?:\[\d+ x i8\]\*|ptr) @(\.str\d+), i32 0, i32 0$')
ALLOCA_RE = re.compile(r'^alloca (.+)$')
STORE_RE = re.compile(r'^store\s+(.+?)\s+(\S+),\s+(.+?)\s+%([\w.]+)\.ptr$')
LOAD_RE = re.compile(r'^load\s+(.+?),\s+(.+?)\s+%([\w.]+)\.ptr$')
TEMP_RE = re.compile(r'%[\w.]+')
CLASSY_RE = re.compile(r'^[A-Z]\w*_\w+$')

BIN_RE = re.compile(r'^(add|sub|mul|sdiv|srem) (i\d+) (\S+), (\S+)$')
CMP_RE = re.compile(r'^icmp (eq|ne|slt|sle|sgt|sge) (i\d+) (\S+), (\S+)$')
BR_UNCOND = re.compile(r'^br label %([\w.$]+)$')
BR_COND = re.compile(r'^br i1 (%[\w.$]+), label %([\w.$]+), label %([\w.$]+)$')
BIN_OPS = {"add": ("+", 1), "sub": ("-", 1), "mul": ("*", 2), "sdiv": ("/", 2), "srem": ("%", 2)}
CMP_OPS = {"eq": "==", "ne": "!=", "slt": "<", "sle": "<=", "sgt": ">", "sge": ">="}
WHILE_FMT = "while ({cond}) {{"
SUPPORTED_FAMILIES = {"while_cond", "while_body", "while_end", "if_then", "if_else", "if_end"}
TRUNC_RE = re.compile(r'^trunc i8 (%[\w.$]+) to i1$')
FCMP_RE = re.compile(r'^fcmp (oeq|one|olt|ole|ogt|oge|une) double (\S+), (\S+)$')
FCMP_OPS = {"oeq": "==", "one": "!=", "une": "!=", "olt": "<", "ole": "<=", "ogt": ">", "oge": ">="}
FNEG_RE = re.compile(r'^fneg double (\S+)$')
FLOAT_OPS = {"mocha_float_add": ("+", 1), "mocha_float_sub": ("-", 1), "mocha_float_mul": ("*", 2)}
IF_FMT = "if ({cond}) {{"
ELSE_OPEN = "} else {"
IF_CLOSE = "};"              # unverified style, measured below
GLOBAL_LOAD_RE = re.compile(r'^load i32, i32\* @([\w.$]+)$')

def block_family(label):
    prev = None
    while prev != label:                      # while_body_31 -> while_body
        prev = label
        label = re.sub(r'[._]?\d+$', '', label)
    return label

PRINTS = {"mocha_print_str", "mocha_print_int", "mocha_print_float", "mocha_print_bool"}
TO_STR = {"mocha_int_to_str", "mocha_float_to_str", "mocha_bool_to_str"}
RENAME = {"mocha_rand_seed": "rand_seed", "mocha_rand_int": "rand_int",
          "mocha_rand_float": "rand_float"}


class EmitError(Exception):
    pass


def quote(s: str) -> str:
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")
    return f'"{s}"'


def var_name(ptr: str) -> str:
    """'e.1' -> 'e' (the compiler adds .N when a name is declared again)."""
    return re.sub(r'\.\d+$', '', ptr)


def mocha_type(llvm: str) -> str:
    llvm = llvm.strip()
    simple = {"double": "float", "i32": "int", "i64": "vast", "i8": "bool", "i8*": "str"}
    if llvm in simple:
        return simple[llvm]
    m = re.match(r'^%struct\.([\w.]+)\*$', llvm)
    if m:
        name = m.group(1)                       # class X -> X; MochaFile -> File
        return name[5:] if name.startswith("Mocha") and len(name) > 5 else name
    raise EmitError(f"can't map the LLVM type {llvm!r} to a Mocha type yet")

BITCAST_RE = re.compile(r'^bitcast (\S+) (%[\w.$]+) to (\S+)$')
ELEM_CALL = re.compile(r'^mocha_(array|array2d|set)_(get|set|init_set|push|insert|has|pop|delete)$')
COLL_SUFFIX = {"%MochaArray*": "[]", "%MochaArray2D*": "[][]", "%MochaSet*": "set",
               "%MochaDict*": "dict", "%MochaTuple*": "tuple"}
SET_CODE = {0: "int", 1: "float", 2: "str", 4: "vast"}
SET_OPS = {"mocha_set_union", "mocha_set_intersect", "mocha_set_xor", "mocha_set_rel_diff"}
BUILTIN_RET = {                     # only entries that agreed everywhere in the corpus
    "mocha_ext_str_split": "str[]",
    "mocha_ext_str_regex_find_all": "str[]",
    "mocha_ext_str_regex_split": "str[]",
    "mocha_ext_float_arr_arr_normalize_col": "float[][]",
    "mocha_ext_float_arr_arr_transpose": "float[][]",
}
RET_MAP = {}          # callee name -> Mocha return type; refilled per module by infer_returns
LIB_SIGS = {}         # library return types, written by lib_sigs.py
_lib_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib_sigs.json")
try:
    with open(_lib_path, encoding="utf-8") as _fh:
        LIB_SIGS.update(json.load(_fh))
except FileNotFoundError:
    print(f"⚠️  {_lib_path} not found: library return types will be unknown "
          f"(run lib_sigs.py from corpus_current\\)", file=sys.stderr)
AMBIG_RET = {"i32", "%MochaArray*", "%MochaArray2D*", "%MochaSet*", "%MochaTuple*"}
RET_RE = re.compile(r'^ret (\S+) (%[\w.$]+)$')

def _elem_type(llvm):
    try:
        return mocha_type(llvm)
    except EmitError:
        return None


def infer_collections(fn):
    """-> {ptr name: (mocha type or None, how)} for every collection local/param of fn.
    how: evidence | creation:<callee> | call:<callee> | inherit | fixed | unknown:<callee or reason>"""
    instrs = [i for l in fn.block_order for i in fn.blocks[l].instrs]
    defs = {i.result: i for i in instrs if i.result}

    def lit(tok):
        if re.fullmatch(r'-?\d+', tok):
            return int(tok)
        d = defs.get(tok)
        m = LIT_INT_RE.match(d.text) if d else None
        return int(m.group(2)) if m else None

    ptr_types, emap, tempvar = {}, {}, {}
    stores = collections.defaultdict(list)
    for i in instrs:
        if i.op == "alloca" and i.result and i.result.endswith(".ptr"):
            m = ALLOCA_RE.match(i.text)
            if m and m.group(1).strip() in COLL_SUFFIX:
                ptr_types[i.result[1:-4]] = m.group(1).strip()
        m = BITCAST_RE.match(i.text)
        if m:
            st, sv, dt = m.groups()
            if dt == "i8*" and st.endswith("*") and i.result:
                emap[i.result] = st[:-1]
            elif st == "i8*" and dt.endswith("*"):
                emap[sv] = dt[:-1]
        if i.op == "store":
            m = STORE_RE.match(i.text)
            if m and m.group(1).strip() in COLL_SUFFIX and m.group(2) != "null":
                tempvar.setdefault(m.group(2), m.group(4))
                stores[m.group(4)].append(m.group(2))

    ev = collections.defaultdict(set)
    for i in instrs:
        if i.op != "call":
            continue
        m = CALL_RE.match(i.text)
        if not m or not ELEM_CALL.match(m.group(2)) or not m.group(3).strip():
            continue
        toks = [a.split()[-1] for a in split_top_level(m.group(3))]
        if len(toks) < 2 or toks[-1] not in emap:
            continue
        first = defs.get(toks[0])
        lm = LOAD_RE.match(first.text) if first else None
        v = lm.group(3) if lm else tempvar.get(toks[0])
        if v:
            ev[v].add(emap[toks[-1]])

    def from_creation(d):
        m = CALL_RE.match(d.text)
        if not m:
            return None, "non-call"
        callee = m.group(2)
        toks = [a.split()[-1] for a in split_top_level(m.group(3))] if m.group(3).strip() else []
        a = [lit(t) for t in toks]
        if callee in ("mocha_array_new", "mocha_array_alloc_filled") and len(a) >= 2 and a[1] == 4:
            return "int[]", f"creation:{callee}"
        if callee == "mocha_array2d_new" and len(a) >= 6:
            if a[2] == 4:
                return "int[][]", f"creation:{callee}"
            if a[2] == 8:
                return ("str[][]" if a[5] == 1 else "float[][]"), f"creation:{callee}"
        if callee == "mocha_set_new" and a and a[0] in SET_CODE:
            return f"set<{SET_CODE[a[0]]}>", f"creation:{callee}"
        if callee == "mocha_dict_new":
            return "dict", f"creation:{callee}"
        if callee == "mocha_tuple_new" and len(a) >= 2 and a[0] and a[1] in (0, 1):
            return f"({'int' if a[1] == 0 else 'str'}, {a[0]})", f"creation:{callee}"
        if callee in BUILTIN_RET:
            return BUILTIN_RET[callee], f"call:{callee}"
        if callee in RET_MAP:
            return RET_MAP[callee], f"ucall:{callee}"
        return None, callee

    out, pending = {}, {}
    for ptr, llvm in ptr_types.items():
        if llvm == "%MochaDict*":
            out[ptr] = ("dict", "fixed")
            continue
        elems = {_elem_type(t) for t in ev.get(ptr, ())}
        if len(elems) == 1 and None not in elems:
            e = next(iter(elems))
            out[ptr] = (f"set<{e}>" if llvm == "%MochaSet*" else e + COLL_SUFFIX[llvm], "evidence") # type: ignore
            continue
        label = "no stores" if not stores[ptr] else "unknown"
        for t in stores[ptr]:
            d = defs.get(t)
            if d is None:
                label = "unknown:param"
                continue
            m = CALL_RE.match(d.text)
            if m and m.group(2) in SET_OPS:
                pending[ptr] = d
                label = "inherit"
                break
            ty, how = from_creation(d)
            if ty:
                out[ptr] = (ty, how)
                break
            label = "unknown:" + how
        else:
            out[ptr] = (None, label)
            continue
        if ptr not in out and ptr not in pending:
            out[ptr] = (None, label)

    for _ in range(3):                                # set ops inherit their first operand's type
        for ptr, d in list(pending.items()):
            m = CALL_RE.match(d.text)
            assert m is not None
            first = defs.get([a.split()[-1] for a in split_top_level(m.group(3))][0])
            lm = LOAD_RE.match(first.text) if first else None
            src_ty = out.get(lm.group(3), (None, ""))[0] if lm else None
            if src_ty:
                out[ptr] = (src_ty, "inherit")
                del pending[ptr]
    for ptr in pending:
        out[ptr] = (None, "unknown:set op on an untyped operand")
    return out


def header(fn) -> str:
    kind, _ = classify_function(fn)
    if kind != "entry":
        raise EmitError(f"{fn.name}: only the entry function is supported so far (kind: {kind})")
    name = fn.name[len("mocha_entry_"):]
    ret = "null" if fn.ret_type == "void" else "?"
    return f"function {name}(didLoad) -> {ret} {{"


def emit_function(fn, g):
    """Returns [(source line, statement text)]. Closing braces have line None and text '};'."""
    bad = sorted({block_family(l) for l in fn.block_order} - {"entry"} - SUPPORTED_FAMILIES)
    if bad:
        raise EmitError(f"{fn.name}: block kinds not supported yet: {', '.join(bad)}")

    loops = {}
    for lp in find_loops(fn):
        if lp["family"] != "while":
            raise EmitError(f"{fn.name}: {lp['family']} loops aren't supported yet")
        loops[lp["header"]] = lp

    ifs = {}
    for info in find_ifs(fn):
        if info["then_exits"] or info["else_exits"]:
            raise EmitError(f"{fn.name}: break/continue/return inside an if isn't supported yet")
        ifs[info["cond_block"]] = info

    defs, uses, var_types = {}, {}, {}
    for label in fn.block_order:
        for i in fn.blocks[label].instrs:
            if i.result:
                defs[i.result] = i
            for t in TEMP_RE.findall(i.text):
                uses[t] = uses.get(t, 0) + 1
            if i.result and i.result.endswith(".ptr"):
                m = ALLOCA_RE.match(i.text)
                if m:
                    var_types[i.result[1:-4]] = mocha_type(m.group(1))

    def once(t, d):
        if uses.get(t, 0) > 1:
            raise EmitError(f"{fn.name}: {t} is used more than once (needs a temp variable)")

    def operand(tok):
        tok = tok.strip()
        return render_p(tok) if tok.startswith("%") else (tok, 9)

    def value(tok):
        return operand(tok)[0]

    def render_p(t):
        """-> (text, precedence); 9 means atom."""
        d = defs.get(t)
        if d is None:
            raise EmitError(f"{fn.name}: {t} is used but not defined")
        m = LIT_INT_RE.match(d.text)
        if m:
            ty, c = m.groups()
            if ty == "i8":
                return {"1": "true", "0": "false"}.get(c, c), 9
            return c, 9
        m = LIT_FLT_RE.match(d.text)
        if m:
            tok = m.group(1)
            try:
                if tok.lower().startswith("0x"):
                    v = struct.unpack('>d', bytes.fromhex(tok[2:].zfill(16)))[0]
                else:
                    v = float(tok)
            except ValueError:
                raise EmitError(f"{fn.name}: can't read the float literal {tok!r}")
            return repr(v), 9
        m = GLOBAL_LOAD_RE.match(d.text)
        if m:
            for enum, tags in g.tags.items():
                for tag in tags:
                    if m.group(1) == f"{enum}__{tag}":
                        return f"{enum}.{tag}", 9
            raise EmitError(f"{fn.name}: load from the unknown global @{m.group(1)}")
        m = LOAD_RE.match(d.text)
        if m:
            return var_name(m.group(3)), 9
        m = BIN_RE.match(d.text)
        if m:
            once(t, d)
            op, _, a, b = m.groups()
            sym, p = BIN_OPS[op]
            (la, pa), (lb, pb) = operand(a), operand(b)
            if pa < p:
                la = f"({la})"
            if pb <= p:
                lb = f"({lb})"
            return f"{la} {sym} {lb}", p
        m = CMP_RE.match(d.text)
        if m:
            once(t, d)
            op, _, a, b = m.groups()
            (la, pa), (lb, pb) = operand(a), operand(b)
            if pa <= 0:
                la = f"({la})"
            if pb <= 0:
                lb = f"({lb})"
            return f"{la} {CMP_OPS[op]} {lb}", 0
        
        m = TRUNC_RE.match(d.text)
        if m:
            once(t, d)
            return operand(m.group(1))
        m = FCMP_RE.match(d.text)
        if m:
            once(t, d)
            op, a, b = m.groups()
            (la, pa), (lb, pb) = operand(a), operand(b)
            if pa <= 0:
                la = f"({la})"
            if pb <= 0:
                lb = f"({lb})"
            return f"{la} {FCMP_OPS[op]} {lb}", 0
        m = FNEG_RE.match(d.text)
        if m:
            once(t, d)
            inner, pi = operand(m.group(1))
            return (f"-({inner})" if pi < 9 else f"-{inner}"), 3
        if d.op == "call":
            cm = CALL_RE.match(d.text)
            if cm and cm.group(2) in FLOAT_OPS:
                once(t, d)
                ftoks = [a.split()[-1] for a in split_top_level(cm.group(3))]
                if len(ftoks) != 2:
                    raise EmitError(f"{fn.name}: {cm.group(2)} with {len(ftoks)} arguments")
                sym, p = FLOAT_OPS[cm.group(2)]
                (la, pa), (lb, pb) = operand(ftoks[0]), operand(ftoks[1])
                if pa < p:
                    la = f"({la})"
                if pb <= p:
                    lb = f"({lb})"
                return f"{la} {sym} {lb}", p
        if d.op == "call":
            once(t, d)
            return render_call(d), 9
        raise EmitError(f"{fn.name}: can't rebuild an expression from: {d.raw[:90]}")

    def parse_call(d):
        m = CALL_RE.match(d.text)
        if not m:
            raise EmitError(f"{fn.name}: can't parse call: {d.raw[:90]}")
        ret, callee, argstr = m.groups()
        toks = [a.split()[-1] for a in split_top_level(argstr)]
        return callee, toks

    def render_call(d):
        callee, toks = parse_call(d)
        if callee == "mocha_str_literal":
            gd = defs.get(toks[0])
            gm = GEP_STR_RE.match(gd.text) if gd else None
            if not gm:
                raise EmitError(f"{fn.name}: string literal from an unknown source: {d.raw[:90]}")
            return quote(g.strings[gm.group(1)])
        if callee in TO_STR:
            return f"str({value(toks[0])})"
        if callee in RENAME:
            return f"{RENAME[callee]}({', '.join(value(t) for t in toks)})"
        if callee.startswith("mocha_"):
            raise EmitError(f"{fn.name}: no rule yet for the call to {callee}")
        if CLASSY_RE.match(callee) or "__" in callee:
            raise EmitError(f"{fn.name}: {callee} looks like a method call (not supported yet)")
        return f"{callee}({', '.join(value(t) for t in toks)})"

    entries, declared, state = [], set(), {"cur": None}

    def process_block(label, ind):
        for i in fn.blocks[label].instrs:
            cur = state["cur"]
            m = LINE_RE.search(i.raw)
            if m:
                state["cur"] = int(m.group(1)) # type: ignore
                continue
            if i.op in ("ret", "br"):
                continue
            if i.op == "alloca" and i.result and i.result.endswith(".ptr"):
                continue
            if i.op == "call":
                if "@mocha_stack_" in i.raw:
                    continue
                callee, toks = parse_call(i)
                if callee in PRINTS:
                    entries.append((cur, "print", (value(toks[0]), toks[1]), ind))
                elif not i.result or uses.get(i.result, 0) == 0:
                    entries.append((cur, "stmt", render_call(i) + ";", ind))
                continue
            if i.op == "store":
                m = STORE_RE.match(i.text)
                if not m or m.group(4) not in var_types:
                    raise EmitError(f"{fn.name}: unsupported store: {i.raw[:90]}")
                ptr = m.group(4)
                name, rhs = var_name(ptr), value(m.group(2))
                if ptr in declared:
                    entries.append((cur, "stmt", f"{name} = {rhs};", ind))
                else:
                    declared.add(ptr)
                    ty = var_types[ptr]
                    em_ = re.fullmatch(r'(\w+)\.\w+', rhs)
                    sd = defs.get(m.group(2))
                    cm = CALL_RE.match(sd.text) if sd is not None and sd.op == "call" else None
                    if ty == "int" and cm and cm.group(2) in RET_MAP:
                        ty = RET_MAP[cm.group(2)]   # an i32 returned by a function declared -> Enum
                    if ty == "int" and em_ and em_.group(1) in g.tags:
                        ty = em_.group(1)           # an i32 initialised from an enum tag
                    entries.append((cur, "stmt", f"var {name}: {ty} = {rhs};", ind))
                continue
            if (LIT_INT_RE.match(i.text) or LIT_FLT_RE.match(i.text) or GEP_STR_RE.match(i.text)
                    or i.op in ("load", "icmp", "fcmp", "trunc", "fneg") or BIN_RE.match(i.text)):
                continue                  # printed where it is used
            raise EmitError(f"{fn.name}: unsupported instruction: {i.raw[:90]}")

    def emit_loop(lp, ind):
        hdr = lp["header"]
        before = len(entries)
        process_block(hdr, ind)
        if len(entries) != before:
            raise EmitError(f"{fn.name}: the while condition contains statements (not supported yet)")
        term = fn.blocks[hdr].instrs[-1]
        m = BR_COND.match(term.text)
        if not m:
            raise EmitError(f"{fn.name}: {hdr} doesn't end in a conditional branch: {term.raw[:70]}")
        cond_t, t_label, f_label = m.groups()
        if f_label != lp["end"]:
            raise EmitError(f"{fn.name}: {hdr} exits to {f_label}, expected {lp['end']}")
        entries.append((state["cur"], "stmt", WHILE_FMT.format(cond=value(cond_t)), ind))
        emit_from(t_label, ind + 1, hdr)
        entries.append((None, "stmt", "};", ind))
        return lp["end"]

    def emit_if(info, ind):
        label = info["cond_block"]
        process_block(label, ind)
        term = fn.blocks[label].instrs[-1]
        m = BR_COND.match(term.text)
        if not m:
            raise EmitError(f"{fn.name}: {label} doesn't end in a conditional branch: {term.raw.strip()[:70]}")
        cond_t, t_label, f_label = m.groups()
        if t_label != f"if_then_{info['id']}":
            raise EmitError(f"{fn.name}: {label}: true branch goes to {t_label}, expected "
                            f"if_then_{info['id']} (negated conditions aren't supported yet)")
        entries.append((state["cur"], "stmt", IF_FMT.format(cond=value(cond_t)), ind))
        emit_from(t_label, ind + 1, info["end"])
        if info["has_else"]:
            entries.append((None, "stmt", ELSE_OPEN, ind))
            emit_from(f_label, ind + 1, info["end"])
        entries.append((None, "stmt", IF_CLOSE, ind))
        return info["end"]

    def emit_from(label, ind, stop):
        steps = 0
        while label is not None and label != stop:
            steps += 1
            if steps > len(fn.block_order) + 5:
                raise EmitError(f"{fn.name}: walking the blocks never reached {stop or 'a return'}")
            if label in loops:
                label = emit_loop(loops[label], ind)
                continue
            if label in ifs:
                label = emit_if(ifs[label], ind)
                continue
            process_block(label, ind)
            term = fn.blocks[label].instrs[-1]
            if term.op == "ret":
                if stop is not None:
                    raise EmitError(f"{fn.name}: return inside a loop or branch isn't supported yet")
                return
            m = BR_UNCOND.match(term.text)
            if not m:
                raise EmitError(f"{fn.name}: {label} ends in '{term.raw.strip()[:60]}' "
                                f"(this kind of branching isn't supported yet)")
            label = m.group(1)

    emit_from(fn.block_order[0], 0, None)

    out, k = [], 0                        # merge print calls from one source line
    while k < len(entries):
        line, kind, payload, ind = entries[k]
        k += 1
        pad = "    " * ind
        if kind != "print":
            out.append((line, pad + payload))
            continue
        args, flag = [payload[0]], payload[1]
        while (flag == "0" and k < len(entries) and entries[k][1] == "print"
               and entries[k][0] == line and entries[k][3] == ind):
            args.append(entries[k][2][0])
            flag = entries[k][2][1]
            k += 1
        out.append((line, pad + "print(" + ", ".join(args)
                    + (", newLine=true);" if flag == "1" else ", newLine=false);")))
    return out


emit_straight = emit_function             # old name, still used by the runner

def infer_returns(funcs, g):
    """Fills RET_MAP for functions with ambiguous LLVM return types.
    Returns {name: (type or None, how)}; how is local | enum | literal | ucall | bcall | <reason>."""
    RET_MAP.clear()
    RET_MAP.update(LIB_SIGS)
    for n in funcs:                    # functions defined in this module shadow library names
        RET_MAP.pop(n, None)
    info = {}
    for _ in range(4):
        changed = False
        for name, fn in funcs.items():
            if name == "main" or fn.ret_type not in AMBIG_RET:
                continue
            instrs = [i for l in fn.block_order for i in fn.blocks[l].instrs]
            defs = {i.result: i for i in instrs if i.result}
            colls = infer_collections(fn) if fn.ret_type != "i32" else {}
            stores = collections.defaultdict(list)
            for i in instrs:
                if i.op == "store":
                    m = STORE_RE.match(i.text)
                    if m:
                        stores[m.group(4)].append(m.group(2))

            def val_type(tok, depth=0):
                if depth > 3:
                    return None, "too deep"
                d = defs.get(tok)
                if d is None:
                    return None, "param"
                m = LIT_INT_RE.match(d.text)
                if m and m.group(1) == "i32":
                    return "int", "literal"
                m = GLOBAL_LOAD_RE.match(d.text)
                if m:
                    for enum, tags in g.tags.items():
                        for tag in tags:
                            if m.group(1) == f"{enum}__{tag}":
                                return enum, "enum"
                    return None, "unknown global"
                m = LOAD_RE.match(d.text)
                if m:
                    var = m.group(3)
                    if fn.ret_type != "i32":
                        ty, how = colls.get(var, (None, "not a collection local"))
                        return ty, ("local" if ty else how)
                    vals = [val_type(v, depth + 1) for v in stores.get(var, [])]
                    kinds = {t for t, _ in vals}
                    if vals and None not in kinds and len(kinds) == 1:
                        return next(iter(kinds)), "local"
                    return None, "local: " + (next((h for t, h in vals if t is None), "never stored"))
                if d.op == "call":
                    m = CALL_RE.match(d.text)
                    callee = m.group(2) if m else "?"
                    if callee in RET_MAP:
                        return RET_MAP[callee], "ucall"
                    if callee in BUILTIN_RET:
                        return BUILTIN_RET[callee], "bcall"
                    return None, f"call:{callee}"
                return None, f"op:{d.op}"

            rets = [RET_RE.match(i.text) for i in instrs if i.op == "ret"]
            vals = [val_type(m.group(2)) for m in rets if m]
            kinds = {t for t, _ in vals}
            if vals and None not in kinds and len(kinds) == 1:
                ty, how = next(iter(kinds)), vals[0][1]
            elif len(kinds - {None}) > 1:
                ty, how = None, "conflicting returns"
            else:
                ty, how = None, next((h for t, h in vals if t is None), "no ret found")
            info[name] = (ty, how)
            if ty and RET_MAP.get(name) != ty:
                RET_MAP[name] = ty
                changed = True
        if not changed:
            break
    return info

def norm(s: str) -> str:
    s = re.sub(r'//.*$', '', s)
    s = re.sub(r'(?<=\d)_(?=\d)', '', s)      # 10_000 -> 10000 (separators aren't in the IR)
    s = re.sub(r'\s+', '', s)
    s = re.sub(r'(\w+)\+\+', r'\1=\1+1', s)   # i++ and i = i + 1 are the same IR
    s = re.sub(r'(\w+)--', r'\1=\1-1', s)
    return s

def src_norm(src, n):
    """Normalised source statement starting on line n; joins continuation lines while a ( or [ is open."""
    k, depth, parts = n - 1, 0, []
    while k < len(src) and len(parts) < 40:
        line = src[k]
        parts.append(norm(line))
        flat = re.sub(r'//.*$', '', re.sub(r'"(?:\\.|[^"\\])*"', '""', line))
        depth += flat.count('(') + flat.count('[') - flat.count(')') - flat.count(']')
        k += 1
        if depth <= 0:
            break
    return "".join(parts)

if __name__ == "__main__":
    stem = sys.argv[1]
    text = open(stem + ".ll", encoding="utf-8").read()
    funcs, g = parse_module(text), parse_globals(text)
    infer_returns(funcs, g)
    src = open(os.path.join("..", stem + ".mch"), encoding="utf-8",
               errors="replace").read().splitlines()
    total = good = 0
    for fn in funcs.values():
        if fn.name == "main":
            continue
        try:
            head, stmts = header(fn), emit_straight(fn, g)
        except EmitError as e:
            print(f"❌ {e}")
            continue
        print(head)
        for n, stmt in stmts:
            if stmt.lstrip().startswith("}"):
                print(f"          {stmt}")
                continue
            ok = n is not None and 1 <= n <= len(src) and src_norm(src, n) == norm(stmt)
            total += 1
            good += ok
            print(f"  {'✅' if ok else '❌'} line {n}:  {stmt}")
            if not ok and n is not None and 1 <= n <= len(src):
                print(f"         source says:  {src[n - 1].strip()}")
        print("};")
    print(f"\n{good}/{total} statements match their source line")