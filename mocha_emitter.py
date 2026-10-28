# mocha_emitter.py
import os
import re
import sys
import json
import struct
import collections
from decimal import Decimal
from mocha_deparser import parse_module, parse_globals, split_top_level, PRELUDE_TYPES
from mocha_classifier import classify_function, find_loops, find_ifs

# ---------------------------------------------------------------- regexes
LINE_RE = re.compile(r'@mocha_stack_update_line\(i32 (\d+)\)')
CALL_RE = re.compile(r'^(?:tail |musttail |notail )?call\s+(.+?)\s+@([\w.$]+)\((.*)\)\s*(?:;.*)?$')
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
FCMP_RE = re.compile(r'^fcmp (oeq|one|olt|ole|ogt|oge|une) double (\S+), (\S+)$')
TRUNC_RE = re.compile(r'^trunc i8 (%[\w.$]+) to i1$')
FNEG_RE = re.compile(r'^fneg double (\S+)$')
BR_UNCOND = re.compile(r'^br label %([\w.$]+)$')
BR_COND = re.compile(r'^br i1 (%[\w.$]+), label %([\w.$]+), label %([\w.$]+)$')
GLOBAL_LOAD_RE = re.compile(r'^load i32, i32\* @([\w.$]+)$')
RET_RE = re.compile(r'^ret (\S+) (%[\w.$]+)$')
RET_VAL_RE = re.compile(r'^ret (?!void)(\S+) (\S+)$')
BITCAST_RE = re.compile(r'^bitcast (\S+) (%[\w.$]+) to (\S+)$')
PLUMBING_RE = re.compile(r'^(rc_retain|rc_release|mocha_ex_pop|free|mocha_file_free|\w+_release|\w+_release_objs|\w+_retain)$') #refcounting, never in the source
SLOT_LOAD_RE = re.compile(r'^load i8, i8\* (%t\d+)$')           # reads the hidden bool slot of an and/or
SLOT_STORE_RE = re.compile(r'^store i8 (\S+), i8\* (%t\d+)$')
ZEXT_RE = re.compile(r'^zext i1 (%[\w.$]+) to i8$')
CAST_RE = re.compile(r'^(?:sitofp i32|sext i32) (%[\w.$]+) to (?:double|i64)$')   # implicit int promotion
SLOT_ANY_LOAD_RE = re.compile(r'^load \S+, \S+\* (%t\d+)$')                    # reads a temp slot (an array get result)
SLOT_STORE_GEN_RE = re.compile(r'^store\s+\S+\s+(\S+),\s+\S+\*\s+(%t\d+)$')    # writes a temp slot (an array set/push value)
GEP_FIELD_RE = re.compile(r'^getelementptr %struct\.(\w+), %struct\.\w+\* (%[\w.$]+), i32 0, i32 (\d+)\s*(?:;.*)?$')
DICT_SET_RE = re.compile(r'^mocha_dict_set_\w+$')
STR_METHODS = {"mocha_str_to_int": ".toInt()", "mocha_str_to_float": ".toFloat()", "mocha_str_length": ".length"}

ARRAY_CALLS = {"mocha_array_get", "mocha_array_set", "mocha_array_push", "mocha_array_init_set",
               "mocha_array2d_get", "mocha_array2d_set"}
METHOD_BUILTINS = {"mocha_file_close": "close", "mocha_file_write": "write",
                   "mocha_file_read": "read", "mocha_file_readline": "readLine",
                   "mocha_complex_add": "add", "mocha_complex_sub": "sub", "mocha_complex_mul": "mul",
                   "mocha_complex_div": "div", "mocha_complex_tostring": "toString"}
EXT_RE = re.compile(r'^mocha_ext_(?:float_arr_arr|int_arr_arr|float_arr|int_arr|str_arr|str|float|int|vast|bool)_(\w+)$')
BIN_OPS = {"add": ("+", 1), "sub": ("-", 1), "mul": ("*", 2), "sdiv": ("/", 2), "srem": ("%", 2)}
CMP_OPS = {"eq": "==", "ne": "!=", "slt": "<", "sle": "<=", "sgt": ">", "sge": ">="}
FCMP_OPS = {"oeq": "==", "one": "!=", "une": "!=", "olt": "<", "ole": "<=", "ogt": ">", "oge": ">="}
FLOAT_OPS = {"mocha_float_add": ("+", 1), "mocha_float_sub": ("-", 1), "mocha_float_mul": ("*", 2),
             "mocha_float_div": ("/", 2), "mocha_str_concat": ("+", 1)}

WHILE_FMT = "while ({cond}) {{"
IF_FMT = "if ({cond}) {{"
ELSE_OPEN = "} else {"
IF_CLOSE = "};"
SUPPORTED_FAMILIES = {"while_cond", "while_body", "while_end", "if_then", "if_else", "if_end",
                      "and_right", "and_done", "or_right", "or_done",
                      "for_cond", "for_body", "for_step", "for_end",
                      "foreach_cond", "foreach_body", "foreach_step", "foreach_end"}

PRINTS = {"mocha_print_str", "mocha_print_int", "mocha_print_float", "mocha_print_bool"}
TO_STR = {"mocha_int_to_str", "mocha_float_to_str", "mocha_bool_to_str"}
RENAME = {"mocha_rand_seed": "rand_seed", "mocha_rand_int": "rand_int", "mocha_rand_float": "rand_float",
          "mocha_user_abs": "abs", "mocha_math_fast_pow": "fast_pow"}

# ---------------------------------------------------------------- type tables
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
AMBIG_RET = {"i32", "%MochaArray*", "%MochaArray2D*", "%MochaSet*", "%MochaTuple*"}
RET_MAP = {}          # callee name -> Mocha return type; refilled per module by infer_returns
LIB_SIGS = {}         # library return types, written by lib_sigs.py
NATIVE_ALIAS = {}     # native callee (ink_new_line_mocha) -> source name (line), written by build_native_aliases.py
try:
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "native_aliases.json"), encoding="utf-8") as _fh:
        NATIVE_ALIAS.update(json.load(_fh))
except FileNotFoundError:
    print("⚠️  native_aliases.json not found: library aliases will print as their native names "
          "(run build_native_aliases.py from corpus_current\\)", file=sys.stderr)

_lib_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib_sigs.json")
try:
    with open(_lib_path, encoding="utf-8") as _fh:
        LIB_SIGS.update(json.load(_fh))
except FileNotFoundError:
    print(f"⚠️  {_lib_path} not found: library return types will be unknown "
          f"(run lib_sigs.py from corpus_current\\)", file=sys.stderr)


class EmitError(Exception):
    pass


def quote(s: str) -> str:
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")
    return f'"{s}"'


def var_name(ptr: str) -> str:
    """'e.1' -> 'e' (the compiler adds .N when a name is declared again)."""
    return re.sub(r'\.\d+$', '', ptr)


def block_family(label):
    prev = None
    while prev != label:                      # while_body_31 -> while_body
        prev = label
        label = re.sub(r'[._]?\d+$', '', label)
    return label


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


def _elem_type(llvm):
    try:
        return mocha_type(llvm)
    except EmitError:
        return None


# ---------------------------------------------------------------- collection type inference
def infer_collections(fn):
    """-> {ptr name: (mocha type or None, how)} for every collection local/param of fn.
    how: evidence | creation:<callee> | call:<callee> | ucall:<callee> | inherit | fixed | unknown:<why>"""
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

def infer_returns(funcs, g):
    """Fills RET_MAP for functions with ambiguous LLVM return types.
    Returns {name: (type or None, how)}."""
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


# ---------------------------------------------------------------- headers
def return_type(fn):
    rt = fn.ret_type
    if rt == "void":
        return "null"
    if rt in AMBIG_RET:
        if fn.name in RET_MAP:
            return RET_MAP[fn.name]
        if rt == "i32":
            return "int"              # all 13 unresolved i32 returns I looked at were declared int
        raise EmitError(f"{fn.name}: can't tell the return type ({rt}) yet")
    return mocha_type(rt)


def owner_of(fn):
    kind = classify_function(fn)[0]
    if kind in ("ctor", "method") and fn.params:
        m = re.match(r'^%struct\.(\w+)\*$', fn.params[0][0])
        if m and fn.name.startswith(m.group(1) + "_"):
            return m.group(1)
    return None


def header(fn) -> str:
    kind, _ = classify_function(fn)
    if kind == "entry":
        name = fn.name[len("mocha_entry_"):]
        extra = "".join(f", {n.lstrip('%')}: {mocha_type(t)}" for t, n in fn.params)
        return f"function {name}(didLoad{extra}) -> {'null' if fn.ret_type == 'void' else '?'} {{"
    if kind not in ("plain", "ctor", "method"):
        raise EmitError(f"{fn.name}: only entry, plain, constructor and method functions are supported so far (kind: {kind})")
    params, name = list(fn.params), fn.name
    if kind in ("ctor", "method"):
        owner = owner_of(fn)
        if owner is None:
            raise EmitError(f"{fn.name}: can't work out which class this {kind} belongs to")
        params, name = params[1:], fn.name[len(owner) + 1:]       # the first parameter is this
    colls = infer_collections(fn)
    parts = []
    for ptype, pname in params:
        pname = pname.lstrip('%')
        if ptype in COLL_SUFFIX:
            ty = colls.get(pname, (None, ""))[0]
            if ty is None:
                raise EmitError(f"{fn.name}: can't tell the type of parameter '{pname}' ({ptype}) from how it is used")
        else:
            ty = mocha_type(ptype)
        parts.append(f"{pname}: {ty}")
    return f"function {name}({', '.join(parts)}) -> {return_type(fn)} {{"


# ---------------------------------------------------------------- bodies
def fmt_float(v):
    if v != v or v in (float("inf"), float("-inf")):
        raise EmitError(f"the float {v!r} has no source form")
    s = format(Decimal(repr(v)), 'f')                       # 5.29177e-11 -> 0.0000000000529177
    return s if '.' in s else s + '.0'


def emit_function(fn, g):
    """Returns [(source line, statement text)]. Closing braces have line None."""
    bad = sorted({block_family(l) for l in fn.block_order} - {"entry"} - SUPPORTED_FAMILIES)
    if bad:
        raise EmitError(f"{fn.name}: block kinds not supported yet: {', '.join(bad)}")

    loops = {}
    for lp in find_loops(fn):
        if lp["family"] not in ("while", "for", "foreach"):
            raise EmitError(f"{fn.name}: {lp['family']} loops aren't supported yet")
        loops[lp["header"]] = lp

    ifs = {}
    for info in find_ifs(fn):
        ifs[info["cond_block"]] = info
    sc, sc_branch = {}, {}          # and/or: hidden slot -> (op, left cond, right value); block -> its 'done' block
    for label in fn.block_order:
        m = BR_COND.match(fn.blocks[label].instrs[-1].text)
        if not m:
            continue
        cond, a, b = m.groups()
        if a.startswith("and_right_"):
            op, right, done = "&&", a, b
        elif b.startswith("or_right_"):
            op, right, done = "||", b, a
        else:
            continue
        rb = fn.blocks[right].instrs
        um = BR_UNCOND.match(rb[-1].text)
        sm = next((SLOT_STORE_RE.match(i.text) for i in rb if SLOT_STORE_RE.match(i.text)), None)
        if not um or um.group(1) != done or not sm:
            raise EmitError(f"{fn.name}: this and/or has a nested and/or on its right side (not supported yet)")
        sc[sm.group(2)] = (op, cond, sm.group(1))
        sc_branch[label] = done

    alloc_cls, obj_cls, ctor_args, ctor_ids, lit2, lit2_tmp = {}, {}, {}, set(), {}, set()
    for label in fn.block_order:
        for i in fn.blocks[label].instrs:
            cm_ = CALL_RE.match(i.text) if i.op == "call" else None
            if cm_ and cm_.group(2) == "rc_alloc" and i.result:
                sz_ = re.search(r'sizeof (\w+)', i.raw)
                if sz_:
                    alloc_cls[i.result] = sz_.group(1)
            elif cm_ and cm_.group(2).endswith("_constructor") and cm_.group(3).strip():
                at_ = [a.split()[-1] for a in split_top_level(cm_.group(3))]
                if at_[0] in obj_cls and cm_.group(2) == obj_cls[at_[0]] + "_constructor":
                    ctor_args[at_[0]] = at_[1:]
                    ctor_ids.add(id(i))
            elif cm_ and cm_.group(2) == "mocha_array2d_new" and i.result:
                a_ = [a.split()[-1] for a in split_top_level(cm_.group(3))]
                if len(a_) >= 4 and a_[3] == "1":
                    lit2_tmp.add(i.result)          # a 2D array literal, filled by array2d_set calls
            bm_ = BITCAST_RE.match(i.text) if i.op == "bitcast" else None
            if bm_ and bm_.group(2) in alloc_cls and bm_.group(3) == f"%struct.{alloc_cls[bm_.group(2)]}*" and i.result:
                obj_cls[i.result] = alloc_cls[bm_.group(2)]

    fld, lit_tmp = {}, set()
    for label in fn.block_order:
        for i in fn.blocks[label].instrs:
            gm_ = GEP_FIELD_RE.match(i.text) if i.op == "getelementptr" else None
            if gm_ and i.result:
                nm_ = re.search(r';\s*field (\w+)', i.raw)
                if nm_:
                    fname_ = nm_.group(1)
                elif gm_.group(1) == "MochaComplex":
                    fname_ = {"0": "real", "1": "imag"}.get(gm_.group(3), f"field{gm_.group(3)}")
                else:
                    fname_ = f"field{gm_.group(3)}"
                fld[i.result] = (gm_.group(2), fname_)
            cm_ = CALL_RE.match(i.text) if i.op == "call" else None
            if cm_ and cm_.group(2) in ("mocha_set_new", "mocha_dict_new") and i.result:
                lit_tmp.add(i.result)
    defs, uses, var_types = {}, {}, {}
    got, slot_val, lit_elems, bc_from, stored_to = {}, {}, {}, {}, {}
    pnames = {n for _, n in fn.params}
    colls = infer_collections(fn)
    for label in fn.block_order:
        for i in fn.blocks[label].instrs:
            if i.result:
                defs[i.result] = i
            cm_ = CALL_RE.match(i.text) if i.op == "call" else None
            if cm_ and (PLUMBING_RE.match(cm_.group(2)) or cm_.group(2) == "mocha_array_init_set"):
                continue                      # releases and array-literal fills are not uses of the value
            if cm_ and cm_.group(2) == "mocha_array2d_set" and cm_.group(3).split()[1].rstrip(",") in lit2_tmp:
                continue                      # filling a 2D array literal
            if cm_ and (cm_.group(2) == "mocha_set_insert" or DICT_SET_RE.match(cm_.group(2))) \
                    and cm_.group(3).split()[1].rstrip(",") in lit_tmp:
                cont_ = cm_.group(3).split()[1].rstrip(",")
                for t in TEMP_RE.findall(i.text):
                    if t != cont_:
                        uses[t] = uses.get(t, 0) + 1      # key and value are used once; the container is not
                continue                      # filling a set / dict literal
            toks_ = TEMP_RE.findall(i.text)
            if id(i) in ctor_ids:
                for t in toks_:
                    if t in obj_cls:
                        toks_.remove(t)       # constructing an object is not a use of it
                        break
            for t in toks_:
                uses[t] = uses.get(t, 0) + 1
            bm = BITCAST_RE.match(i.text)
            if bm and bm.group(1) == "i8*":
                bc_from[bm.group(2)] = i.result        # malloc'd pointer -> its typed slot
            stm = STORE_RE.match(i.text) if i.op == "store" else None
            if stm and stm.group(2).startswith("%t"):
                stored_to.setdefault(stm.group(2), stm.group(4))
            if i.result and i.result.endswith(".ptr"):
                m = ALLOCA_RE.match(i.text)
                if m:
                    name_, llvm_t = i.result[1:-4], m.group(1).strip()
                    if llvm_t in COLL_SUFFIX:
                        ty_ = colls.get(name_, (None, ""))[0]
                        if ty_ is None:
                            raise EmitError(f"{fn.name}: can't tell the type of '{name_}' ({llvm_t}) from how it is used")
                        var_types[name_] = ty_
                    else:
                        var_types[name_] = mocha_type(llvm_t)

    for label in fn.block_order:
        for i in fn.blocks[label].instrs:
            bm_ = BITCAST_RE.match(i.text) if i.op == "bitcast" else None
            if bm_ and bm_.group(3) == "i8*" and bm_.group(1).startswith("%struct.") \
                    and i.result and uses.get(i.result, 0) == 0:
                uses[bm_.group(2)] = uses.get(bm_.group(2), 0) - 1
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
        if t in pnames:                        # a parameter used directly (this, v, ...)
            return t.lstrip("%"), 9
        d = defs.get(t)
        if d is None:
            raise EmitError(f"{fn.name}: {t} is used but not defined")
        if t in obj_cls:
            once(t, d)
            return f"{obj_cls[t]}({', '.join(value(a) for a in ctor_args.get(t, []))})", 9
        m = BITCAST_RE.match(d.text)
        if m and m.group(3).startswith("%struct.") and (m.group(1).startswith("%struct.") or m.group(1) == "i8*"):
            return operand(m.group(2))             # upcast to a parent class: invisible in the source
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
            return fmt_float(v), 9
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
        m = SLOT_LOAD_RE.match(d.text)
        if m and m.group(1) in sc:
            once(t, d)
            op, cond, rv = sc[m.group(1)]
            p = -1 if op == "&&" else -2
            (la, pa), (lb, pb) = operand(cond), operand(rv)
            if pa < p:
                la = f"({la})"
            if pb <= p:
                lb = f"({lb})"
            return f"{la} {op} {lb}", p
        m = SLOT_ANY_LOAD_RE.match(d.text)
        if m and m.group(1) in got:
            once(t, d)
            return got[m.group(1)], 9
        if m and m.group(1) in fld:
            once(t, d)
            obj, fname = fld[m.group(1)]
            return f"{value(obj)}.{fname}", 9
        if m:                                  # a load through a bitcast of a tuple_get result: t#0
            pd = defs.get(m.group(1))
            bm2 = BITCAST_RE.match(pd.text) if pd is not None else None
            sd2 = defs.get(bm2.group(2)) if bm2 and bm2.group(1) == "i8*" else None
            tm2 = CALL_RE.match(sd2.text) if sd2 is not None and sd2.op == "call" else None
            if tm2 and tm2.group(2) == "mocha_tuple_get":
                once(t, d)
                assert bm2 is not None
                return operand(bm2.group(2))
        m = ZEXT_RE.match(d.text) or CAST_RE.match(d.text)
        if m:
            once(t, d)
            return operand(m.group(1))
        m = BIN_RE.match(d.text)
        if m:
            once(t, d)
            op, _, a, b = m.groups()
            sym, p = BIN_OPS[op]
            (la, pa), (lb, pb) = operand(a), operand(b)
            if op == "sub" and la == "0":      # unary minus compiles to 0 - x
                return (f"-({lb})" if pb < 9 or lb.startswith("-") else f"-{lb}"), 3
            if pa < p:
                la = f"({la})"
            if pb <= p or lb.startswith("-"):
                lb = f"({lb})"
            return f"{la} {sym} {lb}", p
        m = CMP_RE.match(d.text)
        if m and m.group(4) == "0" and m.group(1) in ("eq", "ne"):
            sd = defs.get(m.group(3))
            sq = CALL_RE.match(sd.text) if sd is not None and sd.op == "call" else None
            if sq and sq.group(2) == "mocha_str_eq":
                once(t, d)
                once(m.group(3), sd)
                sa = [x.split()[-1] for x in split_top_level(sq.group(3))]
                (la, pa), (lb, pb) = operand(sa[0]), operand(sa[1])
                if pa <= 0:
                    la = f"({la})"
                if pb <= 0:
                    lb = f"({lb})"
                return f"{la} {'==' if m.group(1) == 'ne' else '!='} {lb}", 0
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
                if pb <= p or lb.startswith("-"):
                    lb = f"({lb})"
                return f"{la} {sym} {lb}", p
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

    def arg_types(d):
        m = CALL_RE.match(d.text)
        return [a.rsplit(None, 1)[0] for a in split_top_level(m.group(3))] if m and m.group(3).strip() else []
    def render_call(d):
        callee, toks = parse_call(d)
        if callee == "mocha_str_literal":
            gd = defs.get(toks[0])
            gm = GEP_STR_RE.match(gd.text) if gd else None
            if not gm:
                raise EmitError(f"{fn.name}: string literal from an unknown source: {d.raw[:90]}")
            return quote(g.strings[gm.group(1)])
        if callee == "mocha_array2d_new":
            ptr = stored_to.get(d.result)
            ty = var_types.get(ptr) if ptr else None
            if not ty or not ty.endswith("[][]"):
                raise EmitError(f"{fn.name}: can't tell the element type of a 2D array")
            if ilit(toks[3]) == 1:
                r, c, cells = ilit(toks[0]), ilit(toks[1]), lit2.get(d.result, {})
                if r is None or c is None or any((x, y) not in cells for x in range(r) for y in range(c)):
                    raise EmitError(f"{fn.name}: a 2D array literal I can't rebuild")
                return "[" + ", ".join("[" + ", ".join(cells[(x, y)] for y in range(c)) + "]" for x in range(r)) + "]"
            if ilit(toks[0]) == 0 and ilit(toks[1]) == 0:
                return "[[]]"
            return f"alloc {ty[:-4]}[{value(toks[0])}][{value(toks[1])}]"
        if callee == "mocha_array2d_rows":
            return f"{value(toks[0])}.length"
        if callee == "mocha_array2d_cols":
            return f"{value(toks[0])}.cols"
        if callee == "mocha_array2d_get_row":
            return f"{value(toks[0])}[{value(toks[1])}][]"
        if callee == "mocha_array2d_push_row":
            return f"{value(toks[0])}.push({value(toks[1])})"
        if callee == "mocha_file_open":
            return f"open({', '.join(value(t) for t in toks)})"
        if callee in METHOD_BUILTINS:
            return f"{value(toks[0])}.{METHOD_BUILTINS[callee]}({', '.join(value(t) for t in toks[1:])})"
        if callee in STR_METHODS:
            la, pa = operand(toks[0])
            return (f"({la})" if pa < 9 else la) + STR_METHODS[callee]
        if callee == "mocha_tuple_get":
            return f"{value(toks[0])}#{value(toks[1])}"
        if callee == "mocha_set_new":
            e = lit_elems.get(d.result)
            return ("<" + ", ".join(e[k] for k in sorted(e)) + ">") if e else "<>"
        if callee == "mocha_dict_new":
            e = lit_elems.get(d.result)
            return ("{" + ", ".join(e[k] for k in sorted(e)) + "}") if e else "{}"
        if callee == "mocha_complex_new":
            return f"Complex({value(toks[0])}, {value(toks[1])})"
        em_ext = EXT_RE.match(callee)
        if em_ext:
            r, pr = operand(toks[0])
            if pr < 9 or r[:1] in '"-0123456789':
                r = f"({r})"                   # ("12345").regex_full(...) is how the source writes it
            return f"{r}.{em_ext.group(1)}({', '.join(value(t) for t in toks[1:])})"
        if callee == "mocha_array_length":
            return f"{value(toks[0])}.length"
        if callee == "mocha_array_new":
            elems = lit_elems.get(d.result)
            if elems:
                return "[" + ", ".join(elems[k] for k in sorted(elems)) + "]"
            if toks[0] == "0":
                return "[]"
            raise EmitError(f"{fn.name}: an array of {toks[0]} slots with no initial values (not supported yet)")
        if callee == "mocha_array_alloc_filled":
            ptr = stored_to.get(d.result)
            ty = var_types.get(ptr) if ptr else None
            if not ty or not ty.endswith("[]"):
                raise EmitError(f"{fn.name}: can't tell the element type of an 'alloc' array")
            return f"alloc {ty[:-2]}[{value(toks[0])}]"
        if callee in TO_STR:
            return f"str({value(toks[0])})"
        if callee in RENAME:
            return f"{RENAME[callee]}({', '.join(value(t) for t in toks)})"
        if callee in NATIVE_ALIAS:             # lib\*.mch: function line(...) -> LinePlot native ink_new_line_mocha;
            al = NATIVE_ALIAS[callee]
            if al.startswith("."):             # a class method: the first argument is the receiver
                return f"{value(toks[0])}.{al[1:]}({', '.join(value(t) for t in toks[1:])})"
            return f"{al}({', '.join(value(t) for t in toks)})"
        if callee.startswith("mocha_"):
            raise EmitError(f"{fn.name}: no rule yet for the call to {callee}")
        ats = arg_types(d)
        if ats and ats[0].startswith("%struct.") and ats[0].endswith("*"):
            cls = ats[0][len("%struct."):-1]
            if callee.startswith(cls + "_") and callee != cls + "_constructor":
                return f"{value(toks[0])}.{callee[len(cls) + 1:]}({', '.join(value(t) for t in toks[1:])})"
        if CLASSY_RE.match(callee) or "__" in callee:
            raise EmitError(f"{fn.name}: {callee} looks like a method call (not supported yet)")
        return f"{callee}({', '.join(value(t) for t in toks)})"

    has_pred = set()                   # blocks some branch jumps to; the rest are unreachable
    for label in fn.block_order:
        for tgt in re.findall(r'label %([\w.$]+)', fn.blocks[label].instrs[-1].text):
            has_pred.add(tgt)

    entries, declared, state = [], set(), {"cur": None}

    def slot_for(tok):
        d = defs.get(tok)
        bm = BITCAST_RE.match(d.text) if d is not None else None
        if bm and bm.group(3) == "i8*":
            return bm.group(2)                 # bitcast T* %slot to i8*
        if d is not None and d.op == "alloca" and d.text.strip() == "alloca i8*":
            return tok                         # str[] slot: the alloca IS the argument
        return bc_from.get(tok)                # malloc form: bitcast i8* %p to T*

    def ilit(tok):
        if re.fullmatch(r'-?\d+', tok):
            return int(tok)
        d = defs.get(tok)
        m = LIT_INT_RE.match(d.text) if d is not None else None
        return int(m.group(2)) if m else None

    def do_set(toks, cur, ind):
        slot = slot_for(toks[-1])
        if slot is None or slot not in slot_val:
            raise EmitError(f"{fn.name}: a set insert whose value I can't trace")
        val = value(slot_val[slot])
        if toks[0] in lit_tmp:                 # building a set literal: <a, b, c>
            lit_elems.setdefault(toks[0], {})[len(lit_elems.get(toks[0], {}))] = val
        else:
            entries.append((cur, "stmt", f"{value(toks[0])}.insert({val});", ind))

    def do_dict(toks, cur, ind):
        if len(toks) != 3:
            raise EmitError(f"{fn.name}: a dict set with {len(toks)} arguments")
        key, val = value(toks[1]), value(toks[2])
        if toks[0] in lit_tmp:                 # building a dict literal: {"k": v}
            lit_elems.setdefault(toks[0], {})[len(lit_elems.get(toks[0], {}))] = f"{key}: {val}"
        else:
            entries.append((cur, "stmt", f"{value(toks[0])}[{key}] = {val};", ind))

    def do_array(callee, toks, cur, ind):
        slot = slot_for(toks[-1])
        if slot is None:
            raise EmitError(f"{fn.name}: can't find the value slot for {callee}: {toks[-1]} is {defs[toks[-1]].raw.strip()[:70] if toks[-1] in defs else 'undefined'}")
        two = "array2d" in callee
        if callee.endswith("_get"):
            idx = f"[{value(toks[1])}][{value(toks[2])}]" if two else f"[{value(toks[1])}]"
            got[slot] = f"{value(toks[0])}{idx}"
            return
        if slot not in slot_val:
            raise EmitError(f"{fn.name}: {callee} stores a value I can't trace")
        val = value(slot_val[slot])
        if callee == "mocha_array_init_set":
            lit_elems.setdefault(toks[0], {})[int(toks[1])] = val
        elif two and toks[0] in lit2_tmp:
            lit2.setdefault(toks[0], {})[(ilit(toks[1]), ilit(toks[2]))] = val
        elif callee == "mocha_array_set":
            entries.append((cur, "stmt", f"{value(toks[0])}[{value(toks[1])}] = {val};", ind))
        elif callee == "mocha_array2d_set":
            entries.append((cur, "stmt", f"{value(toks[0])}[{value(toks[1])}][{value(toks[2])}] = {val};", ind))
        else:                                  # push
            entries.append((cur, "stmt", f"{value(toks[0])}.push({val});", ind))

    def process_block(label, ind, skip=0):
        for i in fn.blocks[label].instrs[skip:]:
            cur = state["cur"]
            m = LINE_RE.search(i.raw)
            if m:
                state["cur"] = int(m.group(1)) # type: ignore
                continue
            if i.op == "ret":
                rm = RET_VAL_RE.match(i.text)
                if rm:
                    entries.append((cur, "stmt", f"return {value(rm.group(2))};", ind))
                continue
            if i.op == "br":
                continue
            if i.op == "alloca" and i.result and i.result.endswith(".ptr"):
                continue
            if i.op == "alloca" and ", " not in i.text:
                continue                       # temp slots (and/or flags, array get/set values)
            if i.op == "bitcast":
                continue
            if i.op == "call":
                if "@mocha_stack_" in i.raw:
                    continue
                if id(i) in ctor_ids:
                    continue                   # the object is built where it is used: Class(args)
                callee, toks = parse_call(i)
                if PLUMBING_RE.match(callee):
                    continue
                if callee in ARRAY_CALLS:
                    do_array(callee, toks, cur, ind)
                    continue
                if callee == "mocha_set_insert":
                    do_set(toks, cur, ind)
                    continue
                if DICT_SET_RE.match(callee):
                    do_dict(toks, cur, ind)
                    continue
                if callee == "mocha_array_pop" and toks[-1] == "null":
                    entries.append((cur, "stmt", f"{value(toks[0])}.pop();", ind))
                    continue
                if callee in PRINTS:
                    entries.append((cur, "print", (value(toks[0]), toks[1]), ind))
                elif i.result and uses.get(i.result, 0) == 0 and callee in (
                        "mocha_set_new", "mocha_dict_new", "mocha_array_new", "mocha_array2d_new"):
                    pass                       # an unused collection temp is compiler waste, not a statement
                elif not i.result or uses.get(i.result, 0) == 0:
                    entries.append((cur, "stmt", render_call(i) + ";", ind))
                continue
            if i.op == "store":
                sm_ = SLOT_STORE_RE.match(i.text)
                if sm_ and sm_.group(2) in sc:
                    continue
                sm2 = SLOT_STORE_GEN_RE.match(i.text)
                if sm2 and sm2.group(2) in fld:
                    if cur is None:
                        continue                   # prologue: every field is zeroed before the first source line
                    obj, fname = fld[sm2.group(2)]
                    entries.append((cur, "stmt", f"{value(obj)}.{fname} = {value(sm2.group(1))};", ind))
                    continue
                if sm2:
                    slot_val[sm2.group(2)] = sm2.group(1)    # remembered; the array call that uses it prints it
                    continue
                m = STORE_RE.match(i.text)
                if not m or m.group(4) not in var_types:
                    raise EmitError(f"{fn.name}: unsupported store: {i.raw[:90]}")
                ptr = m.group(4)
                if m.group(2) == "null" and cur is None:
                    continue                   # prologue: pointer locals start out as null
                if m.group(2) in pnames:           # a parameter being copied into its own slot
                    declared.add(ptr)
                    continue
                name, rhs = var_name(ptr), value(m.group(2))
                if ptr in declared:
                    entries.append((cur, "stmt", f"{name} = {rhs};", ind))
                else:
                    declared.add(ptr)
                    ty = var_types[ptr]
                    em_ = re.fullmatch(r'(\w+)\.\w+', rhs)
                    if ty == "int" and em_ and em_.group(1) in g.tags:
                        ty = em_.group(1)           # an i32 initialised from an enum tag
                    sd = defs.get(m.group(2))
                    cm = CALL_RE.match(sd.text) if sd is not None and sd.op == "call" else None
                    if ty == "int" and cm and cm.group(2) in RET_MAP:
                        ty = RET_MAP[cm.group(2)]   # an i32 returned by a function declared -> Enum
                    entries.append((cur, "stmt", f"var {name}: {ty} = {rhs};", ind))
                continue
            if (LIT_INT_RE.match(i.text) or LIT_FLT_RE.match(i.text) or GEP_STR_RE.match(i.text)
                    or i.op in ("load", "icmp", "fcmp", "trunc", "fneg", "zext", "sext", "sitofp", "getelementptr") or BIN_RE.match(i.text)):
                continue                  # printed where it is used
            raise EmitError(f"{fn.name}: unsupported instruction: {i.raw[:90]}")

    loop_stack = []                    # (header, end, continue-target) of the loops we are inside

    def settle(label, ind, skip=0):
        """Process a block; if it ends in an and/or branch, follow it to the block with the real branch."""
        process_block(label, ind, skip)
        while label in sc_branch:
            label = sc_branch[label]
            process_block(label, ind)
        return label

    def loop_header(lp, ind, cond_t, t_label):
        """-> (header text, source line, continue target, first-body-block instructions to skip)"""
        fam, lid, hdr = lp["family"], lp["id"], lp["header"]
        if fam == "while":
            return WHILE_FMT.format(cond=value(cond_t)), state["cur"], hdr, 0
        if fam == "for":
            step = f"for_step_{lid}"
            if not entries or entries[-1][1] != "stmt" or entries[-1][3] != ind \
                    or not re.match(r'(var \w+: [^=]+ = |\w+ = )', entries[-1][2]):
                raise EmitError(f"{fn.name}: a for loop whose initialiser I can't find")
            iline, _, itext, _ = entries.pop()
            saved, mark = state["cur"], len(entries)
            process_block(step, ind)
            st = entries[mark:]
            del entries[mark:]
            state["cur"] = saved
            if len(st) != 1 or st[0][1] != "stmt":
                raise EmitError(f"{fn.name}: the for step isn't a single statement")
            return f"for ({itext[:-1]}; {value(cond_t)}; {st[0][2][:-1]}) {{", iline, step, 0
        step = f"foreach_step_{lid}"            # for each x in arr
        icm = next((i for i in fn.blocks[hdr].instrs if i.op == "icmp"), None)
        cmp_ = CMP_RE.match(icm.text) if icm else None
        bd = defs.get(cmp_.group(4)) if cmp_ else None
        bl = CALL_RE.match(bd.text) if bd is not None and bd.op == "call" else None
        if not bl or bl.group(2) != "mocha_array_length":
            raise EmitError(f"{fn.name}: a for-each over something other than an array (not supported yet)")
        arr_tok = bl.group(3).split()[-1]
        uses[arr_tok] = min(uses.get(arr_tok, 1), 1)       # read once for the length, once per element: still one source use
        body = fn.blocks[t_label].instrs
        k = next((j for j, i in enumerate(body) if i.op == "store" and STORE_RE.match(i.text)), None)
        if k is None:
            raise EmitError(f"{fn.name}: can't find the loop variable of a for-each")
        vptr = STORE_RE.match(body[k].text).group(4) # type: ignore
        declared.add(vptr)
        return f"for each {var_name(vptr)} in {value(arr_tok)} {{", state["cur"], step, k + 1

    def emit_loop(lp, ind):
        hdr = lp["header"]
        before = len(entries)
        last = settle(hdr, ind)
        if len(entries) != before:
            raise EmitError(f"{fn.name}: the loop condition contains statements (not supported yet)")
        m = BR_COND.match(fn.blocks[last].instrs[-1].text)
        if not m:
            raise EmitError(f"{fn.name}: {last} doesn't end in a conditional branch")
        cond_t, t_label, f_label = m.groups()
        if f_label != lp["end"]:
            raise EmitError(f"{fn.name}: {last} exits to {f_label}, expected {lp['end']}")
        head, line, cont, skip = loop_header(lp, ind, cond_t, t_label)
        entries.append((line, "stmt", head, ind))
        loop_stack.append((hdr, lp["end"], cont))
        try:
            emit_from(t_label, ind + 1, hdr if cont == hdr else cont, skip)
        finally:
            loop_stack.pop()
        entries.append((None, "stmt", "};", ind))
        return lp["end"]

    def emit_if(info, ind, skip=0):
        last = settle(info["cond_block"], ind, skip)
        m = BR_COND.match(fn.blocks[last].instrs[-1].text)
        if not m:
            raise EmitError(f"{fn.name}: {last} doesn't end in a conditional branch")
        cond_t, t_label, f_label = m.groups()
        if t_label != f"if_then_{info['id']}":
            raise EmitError(f"{fn.name}: {last}: true branch goes to {t_label}, expected "
                            f"if_then_{info['id']} (negated conditions aren't supported yet)")
        entries.append((state["cur"], "stmt", IF_FMT.format(cond=value(cond_t)), ind))
        emit_from(t_label, ind + 1, info["end"])
        if info["has_else"]:
            entries.append((None, "stmt", ELSE_OPEN, ind))
            emit_from(f_label, ind + 1, info["end"])
        entries.append((None, "stmt", IF_CLOSE, ind))
        return info["end"]

    def emit_from(label, ind, stop, skip=0):
        steps = 0
        while label is not None and label != stop:
            steps += 1
            if steps > len(fn.block_order) + 5:
                raise EmitError(f"{fn.name}: walking the blocks never reached {stop or 'a return'}")
            if label != fn.block_order[0] and label not in has_pred:
                return                 # unreachable: both branches of an if/else already returned
            if label in loops:
                label = emit_loop(loops[label], ind)
                continue
            if label in ifs:
                label = emit_if(ifs[label], ind, skip)
                skip = 0
                continue
            process_block(label, ind, skip)
            skip = 0
            if label in sc_branch:             # and/or: the right side is rendered inside the expression
                label = sc_branch[label]
                continue
            term = fn.blocks[label].instrs[-1]
            if term.op == "ret":
                if stop is not None and term.text.strip() == "ret void":
                    rline = state["cur"]
                    if entries and rline is not None and entries[-1][0] == rline \
                            and entries[-1][1] == "stmt" and not entries[-1][2].endswith("{"):
                        rline += 1             # the compiler gives a bare return no line marker: it sits on the line after
                    entries.append((rline, "stmt", "return;", ind))   # early return; a value return is printed by process_block
                return
            m = BR_UNCOND.match(term.text)
            if not m:
                raise EmitError(f"{fn.name}: {label} ends in '{term.raw.strip()[:60]}' "
                                f"(this kind of branching isn't supported yet)")
            tgt = m.group(1)
            if loop_stack and tgt != stop:
                _, lend, lcont = loop_stack[-1]
                if tgt == lend:
                    entries.append((state["cur"], "stmt", "break;", ind))
                    return
                if tgt == lcont:
                    entries.append((state["cur"], "stmt", "continue;", ind))
                    return
            label = tgt

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
                    + (", newLine=true);" if flag == "1" else ");")))
    return out


emit_straight = emit_function             # old name, still used by the runner


# ---------------------------------------------------------------- checking helpers
FLOAT_TOKEN = re.compile(r'(?<![\w.])(\d+\.\d*(?:[eE][-+]?\d+)?|\d+[eE][-+]?\d+)(?![\w.])')

def norm(s: str) -> str:
    s = re.sub(r'//.*$', '', s)
    s = re.sub(r'(?<=\d)_(?=\d)', '', s)      # 10_000 -> 10000
    s = re.sub(r'\s+', '', s)
    s = re.sub(r'(\w+)\+\+', r'\1=\1+1', s)   # i++ and i = i + 1 are the same IR
    s = re.sub(r'(\w+)--', r'\1=\1-1', s)
    s = s.replace(',newLine=false', '')       # print(x) and print(x, newLine=false) are the same IR
    s = re.sub(r'^(?:private|public)function', 'function', s)    # visibility is not in the IR
    s = s.replace(')->null{', '){')           # the source sometimes omits -> null
    s = re.sub(r'\.rows\b', '.length', s)     # 2D arrays: .rows and .length are the same IR
    s = re.sub(r'alloc\w+\[0\]\[0\]', '[[]]', s)             # alloc T[0][0] and [[]] are the same IR
    s = re.sub(r'\bfloat\(([\w.\[\]]+)\)', r'\1', s)         # float(i) and the implicit int->float promotion are the same IR
    s = re.sub(r'\bfloat\(([^()]*)\)', r'(\1)', s)
    s = s.replace(',}', '}')                  # trailing comma in a multi-line { } literal
    return FLOAT_TOKEN.sub(lambda m: repr(float(m.group(0))), s)   # 1.10 == 1.1


def src_norm(src, n):
    """Normalised source statement starting on line n; joins continuation lines while a ( or [ is open,
    and whole multi-line { ... } literals."""
    first = re.sub(r'//.*$', '', src[n - 1])
    if re.search(r'=\s*\{\s*$', first):
        parts, depth = [norm(first)], 1
        for j in range(n, min(n + 60, len(src))):
            flat = re.sub(r'//.*$', '', re.sub(r'"(?:\\.|[^"\\])*"', '""', src[j]))
            parts.append(norm(src[j]))
            depth += flat.count('{') - flat.count('}')
            if depth <= 0:
                break
        return "".join(parts).replace(",}", "}")
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

def loose(s):
    return re.sub(r'[{};]', '', re.sub(r'(?<=\})else(?=\{)', '', s))

def merge_prints(s):
    for _ in range(4):                        # print(a); print(b); on one line is print(a, b)
        s = re.sub(r'(print\([^;]*)\);print\(', r'\1,', s)
    return s

def line_matches(src, n, stmt):
    a, b = src_norm(src, n), norm(stmt)
    if a == b or merge_prints(a) == merge_prints(b):
        return True
    return "}" in a and loose(a) == loose(b)   # one-line if/else in the source


def source_header(src, name, owner=None):
    lo, hi = 0, len(src)
    if owner:                                  # look only inside 'class Owner { ... };'
        crx = re.compile(r'^\s*class\s+' + re.escape(owner) + r'\b')
        start = next((k for k, l in enumerate(src) if crx.match(l)), None)
        if start is None:
            return None, None
        lo = start
        hi = next((k for k in range(start + 1, len(src)) if src[k].rstrip() == "};"), len(src))
    rx = re.compile(r'\bfunction\s+' + re.escape(name) + r'\s*\(')
    for k in range(lo, hi):
        m = rx.search(src[k])
        if m and '"' not in src[k][:m.start()]:        # skip a header sitting inside a docstring
            parts = []
            for j in range(k, min(k + 12, len(src))):
                parts.append(src[j].strip())
                if '{' in re.sub(r'//.*$', '', src[j]):
                    break
            return k + 1, " ".join(parts)
    return None, None


def header_matches(src, head, owner=None):
    """-> (True/False/None if the source has no such function, source line number, source header text)"""
    n, text = source_header(src, re.match(r'function\s+(\w+)\s*\(', head).group(1), owner) # type: ignore
    if n is None:
        return None, None, None
    return re.sub(r'\};?$', '', norm(text)) == norm(head), n, text # type: ignore


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
        hok, hline, htext = header_matches(src, head)
        print(head + {True: "   ✅ header", False: f"   ❌ header, source says: {htext}",
                      None: "   ⚠️ header not found in source"}[hok])
        for n, stmt in stmts:
            if stmt.lstrip().startswith("}"):
                print(f"          {stmt}")
                continue
            ok = n is not None and 1 <= n <= len(src) and line_matches(src, n, stmt)
            total += 1
            good += ok
            print(f"  {'✅' if ok else '❌'} line {n}:  {stmt}")
            if not ok and n is not None and 1 <= n <= len(src):
                print(f"         source says:  {src[n - 1].strip()}")
        print("};")
    print(f"\n{good}/{total} statements match their source line")