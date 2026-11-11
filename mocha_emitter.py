# mocha_emitter.py
import os
import re
import sys
import json
import struct
import collections
from decimal import Decimal
from mocha_deparser import parse_module, parse_globals, split_top_level, PRELUDE_TYPES
from mocha_classifier import classify_function, find_loops, find_ifs, describe_lc, find_matches, find_trys

# ---------------------------------------------------------------- regexes
LINE_RE = re.compile(r'@mocha_stack_update_line\(i32 (\d+)\)')
CALL_RE = re.compile(r'^(?:tail |musttail |notail )?call\s+(.+?)\s+@([\w.$]+)\((.*)\)\s*(?:;.*)?$')
LIT_INT_RE = re.compile(r'^add (i\d+) 0, (-?\d+)\s*(?:;.*)?$')
LIT_FLT_RE = re.compile(r'^fadd double 0\.0, (\S+)\s*(?:;.*)?$')
GEP_STR_RE = re.compile(
    r'^getelementptr \[\d+ x i8\], (?:\[\d+ x i8\]\*|ptr) @(\.str\d+), i32 0, i32 0$')
ALLOCA_RE = re.compile(r'^alloca (.+)$')
STORE_RE = re.compile(r'^store\s+(.+?)\s+(\S+),\s+(.+?)\s+%([\w.]+)\.ptr$')
LOAD_RE = re.compile(r'^load\s+(.+?),\s+(.+?)\s+%([\w.]+)\.ptr$')
TEMP_RE = re.compile(r'%[\w.]+')
CLASSY_RE = re.compile(r'^[A-Z]\w*_\w+$')

BIN_RE = re.compile(r'^(add|sub|mul|sdiv|srem|and|or|xor|shl|ashr) (i\d+) (\S+), (\S+)$')
CMP_RE = re.compile(r'^icmp (eq|ne|slt|sle|sgt|sge) (i\d+) (\S+), (\S+)$')
PCMP_RE = re.compile(r'^icmp (eq|ne) (%[\w.]+\*|i8\*) (\S+), null$')     # a pointer compared with null
FCMP_RE = re.compile(r'^fcmp (oeq|one|olt|ole|ogt|oge|une) double (\S+), (\S+)$')
TRUNC_RE = re.compile(r'^trunc i8 (%[\w.$]+) to i1$')
FNEG_RE = re.compile(r'^fneg double (\S+)$')
FPTOSI_RE = re.compile(r'^fptosi double (%[\w.$]+) to i32$')
BR_UNCOND = re.compile(r'^br label %([\w.$]+)$')
BR_COND = re.compile(r'^br i1 (%[\w.$]+), label %([\w.$]+), label %([\w.$]+)$')
GLOBAL_LOAD_RE = re.compile(r'^load i32, i32\* @([\w.$]+)$')
RET_RE = re.compile(r'^ret (\S+) (%[\w.$]+)$')
RET_VAL_RE = re.compile(r'^ret (?!void)(\S+) (\S+)$')
BITCAST_RE = re.compile(r'^bitcast (\S+) (%[\w.$]+) to (\S+)$')
INDIRECT_RE = re.compile(r'^(?:tail )?call\s+(\S+)\s+(%[\w.$]+)\((.*)\)\s*(?:;.*)?$')     # a call through a function pointer: call i8 %t57(i8* %t55, i8* %t53)
FNPTR_CAST_RE = re.compile(r'^bitcast i8\* (%[\w.$]+) to .+\)\*$')  
PLUMBING_RE = re.compile(r'^(rc_retain|rc_release|mocha_ex_pop|mocha_ex_push|mocha_ex_env_ptr|mocha_ex_reset_landed|mocha_ex_did_land|mocha_array_retain_elems|RtlCaptureContext|free|mocha_file_free|\w+_release|\w+_release_objs|\w+_retain)$') #refcounting, never in the source
SLOT_LOAD_RE = re.compile(r'^load i8, i8\* (%t\d+)$')           # reads the hidden bool slot of an and/or
SLOT_STORE_RE = re.compile(r'^store i8 (\S+), i8\* (%t\d+)$')
ZEXT_RE = re.compile(r'^zext i1 (%[\w.$]+) to i8$')
CAST_RE = re.compile(r'^(?:sitofp i32|sitofp i64|sext i32) (%[\w.$]+) to (?:double|i64)$')   # implicit int promotion
SLOT_ANY_LOAD_RE = re.compile(r'^load \S+, \S+\* (%t\d+)$')                    # reads a temp slot (an array get result)
SLOT_STORE_GEN_RE = re.compile(r'^store\s+\S+\s+(\S+),\s+\S+\*\s+(%t\d+)$')    # writes a temp slot (an array set/push value)
GEP_FIELD_RE = re.compile(r'^getelementptr %struct\.(\w+), %struct\.\w+\* (%[\w.$]+), i32 0, i32 (\d+)\s*(?:;.*)?$')
DICT_SET_RE = re.compile(r'^mocha_dict_set_\w+$')
STR_METHODS = {"mocha_str_to_int": ".toInt()", "mocha_str_to_float": ".toFloat()", "mocha_str_length": ".length",
               "mocha_str_dictify": ".dictify()"}

ARRAY_CALLS = {"mocha_array_get", "mocha_array_set", "mocha_array_push", "mocha_array_init_set",
               "mocha_array2d_get", "mocha_array2d_set"}
METHOD_BUILTINS = {"mocha_file_close": "close", "mocha_file_write": "write",
                   "mocha_file_read": "read", "mocha_file_readline": "readLine", "mocha_file_eof": "eof",
                   "mocha_sb_append": "append", "mocha_sb_tostring": "toString",
                   "mocha_sb_reverse": "reverse", "mocha_sb_clear": "clear",
                   "mocha_ht_put": "put", "mocha_ht_get": "get", "mocha_ht_has": "has",
                   "mocha_ht_remove": "remove", "mocha_ht_size": "size", "mocha_ht_clear": "clear",
                   "mocha_ht_keys": "keys", "mocha_ht_values": "values",
                   "mocha_complex_add": "add", "mocha_complex_sub": "sub", "mocha_complex_mul": "mul",
                   "mocha_complex_div": "div", "mocha_complex_tostring": "toString"}
EXT_RE = re.compile(r'^mocha_ext_(?:float_arr_arr|int_arr_arr|float_arr|int_arr|str_arr|str|float|int|vast|bool)_(\w+)$')
BIN_OPS = {"add": ("+", 1), "sub": ("-", 1), "mul": ("*", 2), "sdiv": ("/", 2), "srem": ("%", 2),
           "shl": ("<<", 0.5), "ashr": (">>", 0.5), "and": ("&", -0.5), "xor": ("^", -0.6), "or": ("|", -0.7)}
CMP_OPS = {"eq": "==", "ne": "!=", "slt": "<", "sle": "<=", "sgt": ">", "sge": ">="}
COMPLEX_OPS = {"mocha_complex_add": ("+", 1), "mocha_complex_sub": ("-", 1),
               "mocha_complex_mul": ("*", 2), "mocha_complex_div": ("/", 2)}
FCMP_OPS = {"oeq": "==", "one": "!=", "une": "!=", "olt": "<", "ole": "<=", "ogt": ">", "oge": ">="}
FLOAT_OPS = {"mocha_float_add": ("+", 1), "mocha_float_sub": ("-", 1), "mocha_float_mul": ("*", 2),
             "mocha_float_div": ("/", 2), "mocha_float_mod": ("%", 2), "mocha_str_concat": ("+", 1),
             "mocha_int_div": ("/", 2), "mocha_int_mod": ("%", 2)}

WHILE_FMT = "while ({cond}) {{"
IF_FMT = "if ({cond}) {{"
ELSE_OPEN = "} else {"
IF_CLOSE = "};"
SUPPORTED_FAMILIES = {"while_cond", "while_body", "while_end", "if_then", "if_else", "if_end",
                      "and_right", "and_done", "or_right", "or_done",
                      "for_cond", "for_body", "for_step", "for_end",
                      "foreach_cond", "foreach_body", "foreach_step", "foreach_end",
                      "foreach_set_cond", "foreach_set_body", "foreach_set_step", "foreach_set_end",
                      "lc_loop", "lc_body", "lc_append", "lc_skip", "lc_end", "lc_then", "lc_else", "lc_merge", "dowhile_body", "dowhile_end",
                      "match_case", "match_body", "match_default", "match_end",
                      "try_body", "rescue_body", "after_try"}

PRINTS = {"mocha_print_str", "mocha_print_int", "mocha_print_float", "mocha_print_bool", "mocha_print_vast"}
TO_STR = {"mocha_int_to_str", "mocha_float_to_str", "mocha_bool_to_str", "mocha_vast_to_str"}
RENAME = {"mocha_rand_seed": "rand_seed", "mocha_rand_int": "rand_int", "mocha_rand_float": "rand_float",
          "mocha_user_abs": "abs", "mocha_user_round": "round", "mocha_math_fast_pow": "fast_pow", "mocha_tell": "tell"}

# ---------------------------------------------------------------- type tables
ELEM_CALL = re.compile(r'^mocha_(array|array2d|set)_(get|set|init_set|push|insert|has|pop|delete)$')
COLL_SUFFIX = {"%MochaArray*": "[]", "%MochaArray2D*": "[][]", "%MochaSet*": "set",
               "%MochaDict*": "dict", "%MochaTuple*": "tuple"}
SET_CODE = {0: "int", 1: "float", 2: "str", 4: "vast"}
SET_OPS = {"mocha_set_union", "mocha_set_intersect", "mocha_set_xor", "mocha_set_rel_diff"}
BUILTIN_RET = {                     # only entries that agreed everywhere in the corpus
    "mocha_dict_allkeys": "str[]",      # dict keys are always strings
    "mocha_ext_float_arr_arr_singular_values": "float[]",
    "mocha_ext_str_split": "str[]",
    "mocha_ext_str_regex_find_all": "str[]",
    "mocha_ext_str_regex_split": "str[]",
    "mocha_ext_float_arr_arr_normalize_col": "float[][]",
    "mocha_ext_float_arr_arr_transpose": "float[][]",
    "mocha_ext_float_arr_arr_svd": "(float[][], 3)",
    "mocha_ext_float_arr_arr_vector": "float[][]",
    "mocha_ext_float_arr_arr_svd_thin": "(float[][], 2)",
    "mocha_ext_int_arr_arr_vector": "int[][]",
    "mocha_ext_int_arr_arr_svd": "(float[][], 3)",
}
AMBIG_RET = {"i32", "%MochaArray*", "%MochaArray2D*", "%MochaSet*", "%MochaTuple*"}
RET_MAP = {}          # callee name -> Mocha return type; refilled per module by infer_returns
TAG_NAMES = set()     # tag (enum) names of the module being emitted; refilled by infer_returns
MODULE_FUNCS = {}     # function name -> Function of the module being emitted; refilled by infer_returns
FIELD_TYPES = {}      # (struct name, field index) -> Mocha type, from tuple literals stored into class fields
FIELD_NAMES = {}      # (struct name, field index) -> field name, from every GEP in the module that carries a '; field NAME' comment
_FWD_DEPTH = [0]      # guard against forwarding chains that loop
LIB_SIGS = {}         # library return types, written by lib_sigs.py
NATIVE_ALIAS = {}     # native callee (ink_new_line_mocha) -> source name (line), written by build_native_aliases.py
try:
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "native_aliases.json"), encoding="utf-8") as _fh:
        NATIVE_ALIAS.update(json.load(_fh))
except FileNotFoundError:
    print("⚠️  native_aliases.json not found: library aliases will print as their native names "
                "(run build_native_aliases.py from corpus_current\\)", file=sys.stderr)
NATIVE_RET = {}       # native callee -> declared return type, written by build_native_aliases.py
try:
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "native_rets.json"), encoding="utf-8") as _fh:
        NATIVE_RET.update(json.load(_fh))
except FileNotFoundError:
    pass

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
    s = re.sub(r'\\(?!\$)', r'\\\\', s).replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")   # '\$' is Mocha's escape for a literal dollar: keep it single
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
    simple = {"double": "float", "i32": "int", "i64": "vast", "i8": "bool", "i8*": "str", "%MochaDict*": "dict"}
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
    enum_ev = collections.defaultdict(set)     # array -> tag names its literal elements are loaded from (None = not a tag)
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
        sm_ = SLOT_ANY_LOAD_RE.match(first.text) if first else None
        v = lm.group(3) if lm else (tempvar.get(toks[0]) or (sm_.group(1) if sm_ else None))
        if v:
            ev[v].add(emap[toks[-1]])
            if m.group(2) == "mocha_array_init_set" and emap[toks[-1]] == "i32":
                bd_ = defs.get(toks[-1])
                bm_ = BITCAST_RE.match(bd_.text) if bd_ is not None else None
                en_ = None
                for s_ in instrs:
                    sm_ = SLOT_STORE_GEN_RE.match(s_.text) if s_.op == "store" else None
                    if bm_ and sm_ and sm_.group(2) == bm_.group(2):
                        gd_ = defs.get(sm_.group(1))
                        gm_ = GLOBAL_LOAD_RE.match(gd_.text) if gd_ is not None else None
                        if gm_ and gm_.group(1).split("__")[0] in TAG_NAMES:
                            en_ = gm_.group(1).split("__")[0]
                enum_ev[v].add(en_)

    objs_ev = {}                                      # arrays of user-class objects: the release_objs call names the element class (Tensor_release -> Tensor)
    for i in instrs:
        rm_ = CALL_RE.match(i.text) if i.op == "call" else None
        if not rm_ or not re.match(r'^mocha_array2?d?_release_objs$', rm_.group(2)):
            continue
        ra_ = split_top_level(rm_.group(3))
        rld_ = defs.get(ra_[0].split()[-1])
        rlm_ = LOAD_RE.match(rld_.text) if rld_ is not None else None
        rcm_ = re.search(r'@([A-Z]\w*)_release to', rm_.group(3))
        if rlm_ and rcm_:
            objs_ev[rlm_.group(3)] = rcm_.group(1)
        elif rlm_ and "@mocha_complex_release to" in rm_.group(3):
            objs_ev[rlm_.group(3)] = "Complex"        # the runtime's own release function for Complex

    def from_creation(d):
        m = CALL_RE.match(d.text)
        if not m:
            return None, "non-call"
        callee = m.group(2)
        toks = [a.split()[-1] for a in split_top_level(m.group(3))] if m.group(3).strip() else []
        a = [lit(t) for t in toks]
        if callee in ("mocha_array_new", "mocha_array_alloc_filled") and len(a) >= 2 and a[1] == 4:
            return "int[]", f"creation:{callee}"
        if callee in ("mocha_array_new", "mocha_array_alloc_filled") and len(a) >= 2 and a[1] == 1:
            return "bool[]", f"creation:{callee}"      # a 1-byte element is an i8, which only bool uses
        if callee in ("mocha_array_new", "mocha_array_alloc_filled") and len(a) >= 2 and a[1] == 8:      # size 8: number array; float is the default (vast/Complex look identical)
            if any(CALL_RE.match(x_.text) and CALL_RE.match(x_.text).group(2) == "mocha_sort_vast" for x_ in instrs if x_.op == "call"): # type: ignore
                return "vast[]", f"creation:{callee}"          # sort_vast only exists for vast[]
            slots_ = {"%" + y_.group(4) + ".ptr" for y_ in (STORE_RE.match(s_.text) for s_ in instrs if s_.op == "store")
                      if y_ and y_.group(2) == d.result}
            flags_ = set()
            for x_ in instrs:
                rm_ = CALL_RE.match(x_.text) if x_.op == "call" else None
                if not rm_ or rm_.group(2) != "mocha_array_release":
                    continue
                ra_ = split_top_level(rm_.group(3))
                ld_ = defs.get(ra_[0].split()[-1])
                lm2_ = LOAD_RE.match(ld_.text) if ld_ is not None else None
                if len(ra_) == 2 and lm2_ and "%" + lm2_.group(3) + ".ptr" in slots_:
                    flags_.add(ra_[1].split()[-1])
            if flags_ == {"0"}:
                return "float[]", f"creation:{callee}"
            if flags_ == {"1"}:
                return "str[]", f"creation:{callee}"      # the release flag 1 is the str-array flag
        if callee == "mocha_array2d_new" and len(a) >= 6:
            if a[2] == 4:
                return "int[][]", f"creation:{callee}"
            if a[2] == 8:
                return ("str[][]" if a[5] == 1 else "float[][]"), f"creation:{callee}"
        if callee == "mocha_set_new" and a and a[0] in SET_CODE:
            return f"set<{SET_CODE[a[0]]}>", f"creation:{callee}"
        if callee == "mocha_dict_new":
            return "dict", f"creation:{callee}"
        if callee == "mocha_tuple_new" and len(a) >= 2 and a[0] and a[1] == 0:     # scalar tuple: code 0 is shared by int/float/bool/vast, the element slot's pointer type tells them apart
            slot_ty = {"i32": "int", "double": "float", "i8": "bool", "i64": "vast"}
            etys0 = set()
            for x_ in instrs:
                tm_ = CALL_RE.match(x_.text) if x_.op == "call" else None
                if not tm_ or tm_.group(2) != "mocha_tuple_set" or [q.split()[-1] for q in split_top_level(tm_.group(3))][0] != d.result:
                    continue
                sl_ = [q.split()[-1] for q in split_top_level(tm_.group(3))][2]
                bc_ = next((BITCAST_RE.match(z_.text) for z_ in instrs if z_.op == "bitcast" and z_.result
                            and BITCAST_RE.match(z_.text) and BITCAST_RE.match(z_.text).group(1) == "i8*"
                            and BITCAST_RE.match(z_.text).group(2) == sl_), None)
                etys0.add(slot_ty.get(bc_.group(3).rstrip("*")) if bc_ else None)
            ety0 = next(iter(etys0)) if len(etys0) == 1 and None not in etys0 else "int"
            return f"({ety0}, {a[0]})", f"creation:{callee}"
        if callee == "mocha_tuple_new" and len(a) >= 2 and a[0] and a[1] == 1:
            return f"(str, {a[0]})", f"creation:{callee}"
        if callee == "mocha_tuple_new" and len(a) >= 2 and a[0] and a[1] in (2, 3):     # a tuple of 2D (2) or 1D (3) arrays: the type comes from the locals stored into it
            etys = set()
            for x_ in instrs:
                tm_ = CALL_RE.match(x_.text) if x_.op == "call" else None
                if not tm_ or tm_.group(2) != "mocha_tuple_set" or [q.split()[-1] for q in split_top_level(tm_.group(3))][0] != d.result:
                    continue
                sl_ = [q.split()[-1] for q in split_top_level(tm_.group(3))][2]
                slot_ = next((z_.result for z_ in instrs if z_.op == "bitcast" and z_.result and BITCAST_RE.match(z_.text)
                              and BITCAST_RE.match(z_.text).group(1) == "i8*" and BITCAST_RE.match(z_.text).group(2) == sl_), None) # type: ignore
                for y_ in instrs:
                    sm_ = SLOT_STORE_GEN_RE.match(y_.text) if y_.op == "store" else None
                    if slot_ and sm_ and sm_.group(2) == slot_:
                        vd_ = defs.get(sm_.group(1))
                        vl_ = LOAD_RE.match(vd_.text) if vd_ is not None else None
                        etys.add(out.get(vl_.group(3), (None, ""))[0] if vl_ else None)
            if len(etys) == 1 and None not in etys:
                return f"({next(iter(etys))}, {a[0]})", f"creation:{callee}"
        if callee in BUILTIN_RET:
            return BUILTIN_RET[callee], f"call:{callee}"
        if callee in RET_MAP:
            return RET_MAP[callee], f"ucall:{callee}"
        return None, callee

    nested_of = {}                                    # nested comprehension: outer result slot -> element type of the inner arrays
    for i in instrs:
        pm = CALL_RE.match(i.text) if i.op == "call" else None
        if not pm or pm.group(2) != "mocha_array_push":
            continue
        pt = [a.split()[-1] for a in split_top_level(pm.group(3))]
        if len(pt) != 2 or emap.get(pt[1]) != "%MochaArray*":
            continue
        od = defs.get(pt[0])
        om = SLOT_ANY_LOAD_RE.match(od.text) if od is not None else None
        bd = defs.get(pt[1])
        bm = BITCAST_RE.match(bd.text) if bd is not None else None
        if not om or not bm:
            continue
        for s in instrs:
            sm = SLOT_STORE_GEN_RE.match(s.text) if s.op == "store" else None
            if sm and sm.group(2) == bm.group(2):
                vd = defs.get(sm.group(1))
                im = SLOT_ANY_LOAD_RE.match(vd.text) if vd is not None else None
                es = {_elem_type(x) for x in ev.get(im.group(1), ())} if im else set()
                if len(es) == 1 and None not in es:
                    nested_of[om.group(1)] = next(iter(es))
    out, pending = {}, {}
    xm_ = re.match(r'^mocha_ext_(float|int|str|vast|bool)_arr_', fn.name)    # extend float[]: the receiver's element type is in the function name
    if xm_ and fn.params and fn.params[0][1] == "%this":
        out["this"] = (xm_.group(1) + "[]", "fixed")
    for ptr, llvm in ptr_types.items():
        if ptr in out:
            continue                                  # already fixed (the receiver of an extension method)
        if llvm == "%MochaDict*":
            out[ptr] = ("dict", "fixed")
            continue
        if ptr in objs_ev and llvm == "%MochaArray*":
            out[ptr] = (objs_ev[ptr] + "[]", "evidence")
            continue
        if ptr in objs_ev and llvm == "%MochaArray2D*":
            out[ptr] = (objs_ev[ptr] + "[][]", "evidence")
            continue
        elems = {_elem_type(t) for t in ev.get(ptr, ())}
        if len(elems) == 1 and None not in elems:
            e = next(iter(elems))
            if e == "int" and len(enum_ev.get(ptr, ())) == 1 and None not in enum_ev[ptr]:
                e = next(iter(enum_ev[ptr]))       # an i32 array whose literal elements are all tags of one tag type
            out[ptr] = (f"set<{e}>" if llvm == "%MochaSet*" else e + COLL_SUFFIX[llvm], "evidence") # type: ignore
            continue
        label = "no stores" if not stores[ptr] else "unknown"
        for t in stores[ptr]:
            d = defs.get(t)
            if d is None:
                label = "unknown:param"
                continue
            m = CALL_RE.match(d.text)
            def chain_ty_(tok_, depth_=0):                       # copy keeps the type, get_row/get_col drop one [], a call gives RET_MAP, a load gives the local's type
                if depth_ > 6:
                    return None
                d2_ = defs.get(tok_)
                if d2_ is None:
                    return None
                lm2_ = LOAD_RE.match(d2_.text)
                if lm2_:
                    return out.get(lm2_.group(3), (None, ""))[0]
                c2_ = CALL_RE.match(d2_.text) if d2_.op == "call" else None
                if not c2_:
                    return None
                a2_ = [a.split()[-1] for a in split_top_level(c2_.group(3))] if c2_.group(3).strip() else []
                if c2_.group(2) == "mocha_array_copy" and a2_:
                    return chain_ty_(a2_[0], depth_ + 1)
                if c2_.group(2) in ("mocha_array2d_get_row", "mocha_array2d_get_col") and a2_:
                    t2_ = chain_ty_(a2_[0], depth_ + 1)
                    return t2_[:-2] if t2_ and t2_.endswith("[][]") else None
                return RET_MAP.get(c2_.group(2))
            if m and m.group(2) in ("mocha_array_copy", "mocha_array2d_get_row", "mocha_array2d_get_col"):
                cty3_ = chain_ty_(t)
                if cty3_ and cty3_.endswith("[]"):
                    out[ptr] = (cty3_, "inherit")
                    break
            if m and m.group(2) in ("mocha_array2d_get_row", "mocha_array2d_get_col"):      # r = sigma[0] / c = g[][1]: the 2D local's type minus one []
                rad_ = defs.get([a.split()[-1] for a in split_top_level(m.group(3))][0])
                rlm_ = LOAD_RE.match(rad_.text) if rad_ is not None else None
                rty_ = out.get(rlm_.group(3), (None, ""))[0] if rlm_ else None
                if rty_ and rty_.endswith("[][]"):
                    out[ptr] = (rty_[:-2], "inherit")
                    break
            if m and m.group(2) == "mocha_array_copy":      # t = this.items.copy(): the type of the field being copied
                cad_ = defs.get([a.split()[-1] for a in split_top_level(m.group(3))][0])
                clm_ = SLOT_ANY_LOAD_RE.match(cad_.text) if cad_ is not None else None
                cgd_ = defs.get(clm_.group(1)) if clm_ else None
                cgm_ = GEP_FIELD_RE.match(cgd_.text) if cgd_ is not None and cgd_.op == "getelementptr" else None
                cfty_ = FIELD_TYPES.get((cgm_.group(1), cgm_.group(3))) if cgm_ else None
                if cfty_:
                    out[ptr] = (cfty_, "inherit")
                    break
            if m and (m.group(2) in SET_OPS or m.group(2) == "mocha_array_copy"):
                pending[ptr] = d
                label = "inherit"
                break
            sd_ = SLOT_ANY_LOAD_RE.match(d.text)      # a list comprehension result: the element type comes from what the body pushes
            le_ = {_elem_type(x) for x in ev.get(sd_.group(1), ())} if sd_ else set()
            if len(le_) == 1 and None not in le_:
                out[ptr] = (next(iter(le_)) + COLL_SUFFIX[llvm], "evidence") # type: ignore
                break
            if sd_ and sd_.group(1) in nested_of and llvm == "%MochaArray2D*":
                out[ptr] = (nested_of[sd_.group(1)] + "[][]", "evidence")
                break
            if m and m.group(2) == "mocha_array2d_from_rows" and llvm == "%MochaArray2D*":     # [[...] for each ...]: the rows array is the outer comprehension slot, nested_of knows its inner element type
                frd_ = defs.get([a.split()[-1] for a in split_top_level(m.group(3))][0])
                frm_ = SLOT_ANY_LOAD_RE.match(frd_.text) if frd_ is not None else None
                if frm_ and frm_.group(1) in nested_of:
                    out[ptr] = (nested_of[frm_.group(1)] + "[][]", "evidence")
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

    for i in instrs:                                  # a param copied into a typed local: it has the local's type
        sm = STORE_RE.match(i.text) if i.op == "store" else None
        if not sm or sm.group(1).strip() not in COLL_SUFFIX:
            continue
        sd = defs.get(sm.group(2))
        lm = LOAD_RE.match(sd.text) if sd is not None else None
        if lm and lm.group(3) in out and out[lm.group(3)][0] is None and out[lm.group(3)][1] == "unknown:param":
            lt = out.get(sm.group(4), (None, ""))[0]
            if lt:
                out[lm.group(3)] = (lt, "inherit")

    for i in instrs:                                  # a param passed straight into a module function: it has the callee parameter's type
        cm = CALL_RE.match(i.text) if i.op == "call" else None
        callee_fn = MODULE_FUNCS.get(cm.group(2)) if cm else None
        if callee_fn is None or callee_fn is fn or _FWD_DEPTH[0] > 3:
            continue
        assert cm is not None
        ats = [a.split()[-1] for a in split_top_level(cm.group(3))] if cm.group(3).strip() else []
        if len(ats) != len(callee_fn.params):
            continue
        _FWD_DEPTH[0] += 1
        try:
            cout = infer_collections(callee_fn)
        finally:
            _FWD_DEPTH[0] -= 1
        for tok, (_, pname) in zip(ats, callee_fn.params):
            ld = defs.get(tok)
            lm = LOAD_RE.match(ld.text) if ld is not None else None
            if lm and lm.group(3) in out and out[lm.group(3)][0] is None and out[lm.group(3)][1] == "unknown:param":
                cty = cout.get(pname.lstrip('%'), (None, ""))[0]
                if cty:
                    out[lm.group(3)] = (cty, "inherit")
                    
    need_ = [p_ for p_, v_ in out.items() if v_[0] is None and v_[1] == "unknown:param"]
    for cfn in (MODULE_FUNCS.values() if need_ and _FWD_DEPTH[0] == 0 else ()):   # a param whose callers pass a typed local: it has that local's type
        if cfn is fn or _FWD_DEPTH[0] > 3:
            continue
        cinstrs = [x for l in cfn.block_order for x in cfn.blocks[l].instrs]
        cdefs = {x.result: x for x in cinstrs if x.result}
        for x in cinstrs:
            cm = CALL_RE.match(x.text) if x.op == "call" else None
            if not cm or cm.group(2) != fn.name or not cm.group(3).strip():
                continue
            ats = [a.split()[-1] for a in split_top_level(cm.group(3))]
            if len(ats) != len(fn.params):
                continue
            _FWD_DEPTH[0] += 1
            try:
                ccolls = infer_collections(cfn)
            finally:
                _FWD_DEPTH[0] -= 1
            for tok, (_, pname) in zip(ats, fn.params):
                pn = pname.lstrip('%')
                ld = cdefs.get(tok)
                lm = LOAD_RE.match(ld.text) if ld is not None else None
                if lm and pn in out and out[pn][0] is None and out[pn][1] == "unknown:param":
                    cty = ccolls.get(lm.group(3), (None, ""))[0]
                    if cty:
                        out[pn] = (cty, "inherit")
                uc_ = CALL_RE.match(ld.text) if ld is not None and ld.op == "call" else None
                if uc_ and uc_.group(2) in RET_MAP and pn in out and out[pn][0] is None and out[pn][1] == "unknown:param":
                    out[pn] = (RET_MAP[uc_.group(2)], "inherit")      # len_of(mk(3)): the argument is a call whose return type is known
                cp_ = CALL_RE.match(ld.text) if ld is not None and ld.op == "call" else None
                if cp_ and cp_.group(2) == "mocha_array_copy" and pn in out and out[pn][0] is None and out[pn][1] == "unknown:param":
                    ctok_ = [a.split()[-1] for a in split_top_level(cp_.group(3))][0]
                    cld_ = cdefs.get(ctok_)
                    clm2_ = LOAD_RE.match(cld_.text) if cld_ is not None else None
                    cty2_ = ccolls.get(clm2_.group(3), (None, ""))[0] if clm2_ else None
                    if cty2_:
                        out[pn] = (cty2_, "inherit")
                am_ = CALL_RE.match(ld.text) if ld is not None and ld.op == "call" else None
                if am_ and am_.group(2) in ("mocha_array_new", "mocha_array_alloc_filled") and pn in out and out[pn][0] is None and out[pn][1] == "unknown:param":
                    at2_ = [a.split()[-1] for a in split_top_level(am_.group(3))]      # sortInts([3, 1, 4]): a literal array passed straight in, its element size gives the type
                    sd_ = cdefs.get(at2_[1]) if len(at2_) > 1 else None
                    sm2_ = LIT_INT_RE.match(sd_.text) if sd_ is not None else None
                    sz_ = int(at2_[1]) if len(at2_) > 1 and re.fullmatch(r'-?\d+', at2_[1]) else (int(sm2_.group(2)) if sm2_ else None)
                    if sz_ in (4, 1):
                        out[pn] = ({4: "int[]", 1: "bool[]"}[sz_], "inherit")
                rm_ = CALL_RE.match(ld.text) if ld is not None and ld.op == "call" else None
                if rm_ and rm_.group(2) == "mocha_array2d_get_row" and pn in out and out[pn][0] is None and out[pn][1] == "unknown:param":
                    rtok_ = [a.split()[-1] for a in split_top_level(rm_.group(3))][0]
                    rld_ = cdefs.get(rtok_)
                    rlm_ = LOAD_RE.match(rld_.text) if rld_ is not None else None
                    rty_ = ccolls.get(rlm_.group(3), (None, ""))[0] if rlm_ else None
                    if rty_ and rty_.endswith("[][]"):
                        out[pn] = (rty_[:-2], "inherit")

    for i in instrs:                                  # xs = points#k: the local is stored from a load of a bitcast tuple_get
        sm = STORE_RE.match(i.text) if i.op == "store" else None
        if not sm or sm.group(1).strip() not in COLL_SUFFIX or out.get(sm.group(4), (1, ""))[0] is not None:
            continue
        ld = defs.get(sm.group(2))
        lm = SLOT_ANY_LOAD_RE.match(ld.text) if ld is not None else None
        bd = defs.get(lm.group(1)) if lm else None
        bm = BITCAST_RE.match(bd.text) if bd is not None else None
        gd = defs.get(bm.group(2)) if bm else None
        gm = CALL_RE.match(gd.text) if gd is not None and gd.op == "call" else None
        if not gm or gm.group(2) != "mocha_tuple_get":
            continue
        ga = [a.split()[-1] for a in split_top_level(gm.group(3))]
        td = defs.get(ga[0])
        tl = LOAD_RE.match(td.text) if td is not None else None
        tty = out.get(tl.group(3), (None, ""))[0] if tl else None
        em = re.fullmatch(r'\((.+), (\d+)\)', tty) if tty else None
        if em:
            out[sm.group(4)] = (em.group(1), "inherit")

    for i in instrs:                                  # a local copied from a class field: its type is what the module stores into that field
        sm = STORE_RE.match(i.text) if i.op == "store" else None
        if not sm or sm.group(1).strip() not in COLL_SUFFIX or out.get(sm.group(4), (1, ""))[0] is not None:
            continue
        ld = defs.get(sm.group(2))
        lm = SLOT_ANY_LOAD_RE.match(ld.text) if ld is not None else None
        gd = defs.get(lm.group(1)) if lm else None
        gm = GEP_FIELD_RE.match(gd.text) if gd is not None and gd.op == "getelementptr" else None
        fty = FIELD_TYPES.get((gm.group(1), gm.group(3))) if gm else None
        if fty:
            out[sm.group(4)] = (fty, "inherit")
    
    for _ in range(3):                                # a local copied from another typed local: var u = t
        for i in instrs:
            sm = STORE_RE.match(i.text) if i.op == "store" else None
            if not sm or sm.group(1).strip() not in COLL_SUFFIX or out.get(sm.group(4), (1, ""))[0] is not None:
                continue
            ld = defs.get(sm.group(2))
            lm = LOAD_RE.match(ld.text) if ld is not None else None
            if lm and lm.group(3) != sm.group(4) and out.get(lm.group(3), (None, ""))[0]:
                out[sm.group(4)] = (out[lm.group(3)][0], "inherit")
    
    for _ in range(3):                                # set ops inherit their first operand's type
        for ptr, d in list(pending.items()):
            m = CALL_RE.match(d.text)
            assert m is not None
            first = defs.get([a.split()[-1] for a in split_top_level(m.group(3))][0])
            for _depth in range(5):                   # a chain like a.intersect(b).union(c): follow the first operand down to a load
                fm_ = CALL_RE.match(first.text) if first is not None and first.op == "call" else None
                if not fm_ or fm_.group(2) not in SET_OPS:
                    break
                first = defs.get([a.split()[-1] for a in split_top_level(fm_.group(3))][0])
            lm = LOAD_RE.match(first.text) if first else None
            src_ty = out.get(lm.group(3), (None, ""))[0] if lm else None
            if src_ty:
                out[ptr] = (src_ty, "inherit")
                del pending[ptr]
    for ptr in pending:
        out[ptr] = (None, "unknown:set op on an untyped operand")
    return out

def build_field_types(funcs):
    """(struct, field index) -> type, for fields that a tuple literal is stored into. Conflicting writers give None."""
    out = {}
    for fn in funcs.values():
        instrs = [i for l in fn.block_order for i in fn.blocks[l].instrs]
        defs = {i.result: i for i in instrs if i.result}
        gep = {}
        for i in instrs:
            gm = GEP_FIELD_RE.match(i.text) if i.op == "getelementptr" else None
            if gm and i.result:
                gep[i.result] = (gm.group(1), gm.group(3))
        for i in instrs:
            sm = SLOT_STORE_GEN_RE.match(i.text) if i.op == "store" else None
            if not sm or sm.group(2) not in gep:
                continue
            d = defs.get(sm.group(1))
            cm = CALL_RE.match(d.text) if d is not None and d.op == "call" else None
            if not cm or cm.group(2) != "mocha_tuple_new":
                continue
            a = []
            for t in [x.split()[-1] for x in split_top_level(cm.group(3))]:
                ld = defs.get(t)
                lm = LIT_INT_RE.match(ld.text) if ld is not None else None
                a.append(int(t) if re.fullmatch(r'-?\d+', t) else (int(lm.group(2)) if lm else None))
            if len(a) >= 2 and a[0] and a[1] in (0, 1):
                ty = f"({'int' if a[1] == 0 else 'str'}, {a[0]})"
                key = gep[sm.group(2)]
                out[key] = ty if out.get(key, ty) == ty else None
    for fn in funcs.values():              # an array in a class field: pushes, gets and sets through the field give its element type
        instrs = [i for l in fn.block_order for i in fn.blocks[l].instrs]
        defs = {i.result: i for i in instrs if i.result}
        gep, emap = {}, {}
        for i in instrs:
            gm = GEP_FIELD_RE.match(i.text) if i.op == "getelementptr" else None
            if gm and i.result:
                gep[i.result] = (gm.group(1), gm.group(3))
            bm = BITCAST_RE.match(i.text) if i.op == "bitcast" else None
            if bm:
                st, sv, dt = bm.groups()
                if dt == "i8*" and st.endswith("*") and i.result:
                    emap[i.result] = st[:-1]
                elif st == "i8*" and dt.endswith("*"):
                    emap[sv] = dt[:-1]
        for i in instrs:
            cm = CALL_RE.match(i.text) if i.op == "call" else None
            if not cm or cm.group(2) not in ("mocha_array_get", "mocha_array_set", "mocha_array_push") or not cm.group(3).strip():
                continue
            toks = [a.split()[-1] for a in split_top_level(cm.group(3))]
            if len(toks) < 2 or toks[-1] not in emap:
                continue
            fd = defs.get(toks[0])
            lm = re.match(r'^load %MochaArray\*, %MochaArray\*\* (%t\d+)\s*(?:;.*)?$', fd.text) if fd is not None else None
            et = _elem_type(emap[toks[-1]])
            if not lm or lm.group(1) not in gep or et is None:
                continue
            key, ty = gep[lm.group(1)], et + "[]"
            out[key] = ty if out.get(key, ty) == ty else None
    for fn in funcs.values():              # a 1D array stored into a class field: element size 4 is int[], 1 is bool[]
        instrs = [i for l in fn.block_order for i in fn.blocks[l].instrs]
        defs = {i.result: i for i in instrs if i.result}
        gep = {}
        for i in instrs:
            gm = GEP_FIELD_RE.match(i.text) if i.op == "getelementptr" else None
            if gm and i.result:
                gep[i.result] = (gm.group(1), gm.group(3))
        for i in instrs:
            cm = CALL_RE.match(i.text) if i.op == "call" else None
            if not cm or cm.group(2) not in ("mocha_array_new", "mocha_array_alloc_filled") or not i.result:
                continue
            sz = [x.split()[-1] for x in split_top_level(cm.group(3))]
            if len(sz) < 2:
                continue
            code = int(sz[1]) if re.fullmatch(r'-?\d+', sz[1]) else None
            ty = {4: "int[]", 1: "bool[]"}.get(code) # type: ignore
            if not ty:
                continue
            for s in instrs:
                sm = SLOT_STORE_GEN_RE.match(s.text) if s.op == "store" else None
                if sm and sm.group(1) == i.result and sm.group(2) in gep:
                    key = gep[sm.group(2)]
                    out[key] = ty if out.get(key, ty) == ty else None
    for fn in funcs.values():              # a 2D array literal stored into a class field: the creation args give its type
        instrs = [i for l in fn.block_order for i in fn.blocks[l].instrs]
        defs = {i.result: i for i in instrs if i.result}
        gep = {}
        for i in instrs:
            gm = GEP_FIELD_RE.match(i.text) if i.op == "getelementptr" else None
            if gm and i.result:
                gep[i.result] = (gm.group(1), gm.group(3))

        def lit2(tok):
            if re.fullmatch(r'-?\d+', tok):
                return int(tok)
            d_ = defs.get(tok)
            m_ = LIT_INT_RE.match(d_.text) if d_ is not None else None
            return int(m_.group(2)) if m_ else None
        for i in instrs:
            cm = CALL_RE.match(i.text) if i.op == "call" else None
            if not cm or cm.group(2) != "mocha_array2d_new" or not i.result:
                continue
            a = [lit2(x.split()[-1]) for x in split_top_level(cm.group(3))]
            if len(a) < 6 or a[2] not in (4, 8):
                continue
            ty = "int[][]" if a[2] == 4 else ("str[][]" if a[5] == 1 else "float[][]")
            for s in instrs:
                sm = SLOT_STORE_GEN_RE.match(s.text) if s.op == "store" else None
                if sm and sm.group(1) == i.result and sm.group(2) in gep:
                    key = gep[sm.group(2)]
                    out[key] = ty if out.get(key, ty) == ty else None
    return out

def infer_returns(funcs, g):
    """Fills RET_MAP for functions with ambiguous LLVM return types.
    Returns {name: (type or None, how)}."""
    RET_MAP.clear()
    RET_MAP.update(LIB_SIGS)
    TAG_NAMES.clear()
    TAG_NAMES.update(g.tags)
    MODULE_FUNCS.clear()
    MODULE_FUNCS.update(funcs)
    FIELD_TYPES.clear()
    FIELD_TYPES.update(build_field_types(funcs))
    FIELD_NAMES.clear()
    for fn_ in funcs.values():
        for l_ in fn_.block_order:
            for i_ in fn_.blocks[l_].instrs:
                gm_ = GEP_FIELD_RE.match(i_.text) if i_.op == "getelementptr" else None
                nm_ = re.search(r';\s*field (\w+)', i_.raw) if gm_ else None
                if gm_ and nm_:
                    FIELD_NAMES.setdefault((gm_.group(1), gm_.group(3)), nm_.group(1))
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
                fl_ = SLOT_ANY_LOAD_RE.match(d.text) if d.op == "load" else None      # return this.data: a load of a class field
                fgd_ = defs.get(fl_.group(1)) if fl_ else None
                fgm_ = GEP_FIELD_RE.match(fgd_.text) if fgd_ is not None and fgd_.op == "getelementptr" else None
                if fgm_ and FIELD_TYPES.get((fgm_.group(1), fgm_.group(3))):
                    return FIELD_TYPES[(fgm_.group(1), fgm_.group(3))], "field load"
                if d.op == "call":
                    m = CALL_RE.match(d.text)
                    callee = m.group(2) if m else "?"
                    if callee == "mocha_tuple_new":          # return (a, b): every element is a local copied into a malloc'd slot
                        etys, n = set(), 0
                        for x in instrs:
                            tm = CALL_RE.match(x.text) if x.op == "call" else None
                            if not tm or tm.group(2) != "mocha_tuple_set":
                                continue
                            ta = [a.split()[-1] for a in split_top_level(tm.group(3))]
                            if ta[0] != tok:
                                continue
                            n += 1
                            bd = defs.get(ta[2])
                            sm = None
                            for y in instrs:
                                if y.op == "bitcast" and BITCAST_RE.match(y.text) and BITCAST_RE.match(y.text).group(2) == ta[2]: # type: ignore
                                    for z in instrs:
                                        if z.op == "store" and SLOT_STORE_GEN_RE.match(z.text) and SLOT_STORE_GEN_RE.match(z.text).group(2) == y.result: # type: ignore
                                            sm = SLOT_STORE_GEN_RE.match(z.text).group(1) # type: ignore
                            ety = val_type(sm, depth + 1)[0] if sm else None
                            etys.add(ety)
                        if n and len(etys) == 1 and None not in etys:
                            return f"({next(iter(etys))}, {n})", "tuple"
                        return None, "tuple elements I can't type"
                    if callee in RET_MAP:
                        return RET_MAP[callee], "ucall"
                    if callee in BUILTIN_RET:
                        return BUILTIN_RET[callee], "bcall"
                    if callee == "mocha_array_copy":         # return this.items.copy(): the type of the field it copies
                        assert m is not None
                        ad_ = defs.get([a.split()[-1] for a in split_top_level(m.group(3))][0])
                        lm_ = SLOT_ANY_LOAD_RE.match(ad_.text) if ad_ is not None else None
                        gd_ = defs.get(lm_.group(1)) if lm_ else None
                        gm_ = GEP_FIELD_RE.match(gd_.text) if gd_ is not None and gd_.op == "getelementptr" else None
                        fty_ = FIELD_TYPES.get((gm_.group(1), gm_.group(3))) if gm_ else None
                        if fty_:
                            return fty_, "field copy"
                        pl_ = LOAD_RE.match(ad_.text) if ad_ is not None else None   # return a.copy(): the type of the local or param being copied
                        lty_ = infer_collections(fn).get(pl_.group(3), (None, ""))[0] if pl_ else None
                        if lty_:
                            return lty_, "local copy"
                    if callee == "mocha_array2d_get_col":    # return this.cells[][k]: a column of the 2D field has the row element type
                        assert m is not None
                        ad_ = defs.get([a.split()[-1] for a in split_top_level(m.group(3))][0])
                        lm_ = SLOT_ANY_LOAD_RE.match(ad_.text) if ad_ is not None else None
                        gd_ = defs.get(lm_.group(1)) if lm_ else None
                        gm_ = GEP_FIELD_RE.match(gd_.text) if gd_ is not None and gd_.op == "getelementptr" else None
                        fty_ = FIELD_TYPES.get((gm_.group(1), gm_.group(3))) if gm_ else None
                        if fty_ and fty_.endswith("[][]"):
                            return fty_[:-2], "field col"
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
    if kind == "ext_method" and fn.params:
        m_ext = re.match(r'^mocha_ext_(.+?)_([^_]+(?:_[^_]+)*)$', fn.name)
        ext_ty = {"double": "float", "i32": "int", "i64": "vast"}.get(fn.params[0][0])
        if fn.params[0][0].startswith("%struct.Mocha"):
            ext_ty = fn.params[0][0][len("%struct.Mocha"):-1]
        pre = None
        for cand in ("float_arr", "int_arr", "str_arr", "float", "int", "vast", "str", "bool", ext_ty or ""):
            if cand and fn.name.startswith(f"mocha_ext_{cand}_"):
                pre = f"mocha_ext_{cand}_"
                break
        if pre is None:
            raise EmitError(f"{fn.name}: can't work out the receiver type of this extension method")
        eparams = ", ".join(f"{n.lstrip('%')}: {mocha_type(t)}" for t, n in fn.params[1:])
        return f"function {fn.name[len(pre):]}({eparams}) -> {return_type(fn)} {{"
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
            if ptype == "i8*":                      # an i8* param whose loaded value is cast to i8** and read for a function pointer is a lambda
                all2_ = [x_ for l_ in fn.block_order for x_ in fn.blocks[l_].instrs]
                d2_ = {x_.result: x_ for x_ in all2_ if x_.result}
                for x_ in all2_:
                    bm2_ = BITCAST_RE.match(x_.text) if x_.op == "bitcast" else None
                    ld2_ = d2_.get(bm2_.group(2)) if bm2_ and bm2_.group(1) == "i8*" and bm2_.group(3) == "i8**" else None
                    if ld2_ is not None and ld2_.op == "load" and ld2_.text.endswith(f"%{pname}.ptr"):
                        ty = "lambda"
            if ptype == "i32":                      # an i32 param compared against tags of one enum is that enum
                all_ = [x_ for l_ in fn.block_order for x_ in fn.blocks[l_].instrs]
                d_ = {x_.result: x_ for x_ in all_ if x_.result}
                pl_ = {x_.result for x_ in all_ if x_.op == "load" and x_.text.endswith(f"%{pname}.ptr")}
                en_set = set()
                for x_ in all_:
                    cm_ = CMP_RE.match(x_.text) if x_.op == "icmp" else None
                    if not cm_ or cm_.group(1) not in ("eq", "ne"):
                        continue
                    a_, b_ = cm_.group(3), cm_.group(4)
                    if a_ in pl_ or b_ in pl_:
                        o_ = d_.get(b_ if a_ in pl_ else a_)
                        gm_ = GLOBAL_LOAD_RE.match(o_.text) if o_ is not None else None
                        if gm_ and "__" in gm_.group(1):
                            en_set.add(gm_.group(1).split("__")[0])
                if len(en_set) == 1 and next(iter(en_set)) in TAG_NAMES:
                    ty = next(iter(en_set))
                if ty == "int" and not en_set:       # never compared against a tag here: every caller passing a tag of one enum makes it that enum
                    pidx_ = [n_.lstrip('%') for _, n_ in fn.params].index(pname)
                    cen_ = set()
                    for cf_ in MODULE_FUNCS.values():
                        ci_ = [x_ for l_ in cf_.block_order for x_ in cf_.blocks[l_].instrs]
                        cd_ = {x_.result: x_ for x_ in ci_ if x_.result}
                        for x_ in ci_:
                            cm2_ = CALL_RE.match(x_.text) if x_.op == "call" else None
                            if not cm2_ or cm2_.group(2) != fn.name or not cm2_.group(3).strip():
                                continue
                            at_ = [a.split()[-1] for a in split_top_level(cm2_.group(3))]
                            if len(at_) != len(fn.params):
                                continue
                            ad_ = cd_.get(at_[pidx_])
                            gm3_ = GLOBAL_LOAD_RE.match(ad_.text) if ad_ is not None else None
                            cen_.add(gm3_.group(1).split("__")[0] if gm3_ and "__" in gm3_.group(1) else None)
                    if len(cen_) == 1 and None not in cen_ and next(iter(cen_)) in TAG_NAMES:
                        ty = next(iter(cen_))
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
        if lp["family"] not in ("while", "for", "foreach", "foreach_set", "lc", "dowhile"):
            raise EmitError(f"{fn.name}: {lp['family']} loops aren't supported yet")
        loops[lp["header"]] = lp

    ifs = {}
    for info in find_ifs(fn):
        ifs[info["cond_block"]] = info
    sc, sc_branch = {}, {}          # and/or: hidden slot -> (op, left cond, right value); block -> its 'done' block
    sc_right_blocks = []            # right-hand blocks of every and/or
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
        sc_right_blocks.append(right)

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
                elif (gm_.group(1), gm_.group(3)) in FIELD_NAMES:
                    fname_ = FIELD_NAMES[(gm_.group(1), gm_.group(3))]      # the comment is missing here, but another GEP in the module names this field
                else:
                    fname_ = f"field{gm_.group(3)}"
                fld[i.result] = (gm_.group(2), fname_)
            cm_ = CALL_RE.match(i.text) if i.op == "call" else None
            if cm_ and cm_.group(2) in ("mocha_set_new", "mocha_dict_new", "mocha_tuple_new") and i.result:
                lit_tmp.add(i.result)
    defs, uses, var_types = {}, {}, {}
    lc_text, lc_state = {}, {"on": False, "expr": None, "slot": None}   # list comprehensions: finished text per result slot, and the one being read
    lc_idx_slots, lc_var_name = set(), {}      # new compiler: the comprehension counter and loop variable are anonymous slots
    for lp_ in loops.values():
        if lp_["family"] != "lc":
            continue
        hi_ = next((i for i in fn.blocks[lp_["header"]].instrs if i.op == "load"), None)
        lm_ = SLOT_ANY_LOAD_RE.match(hi_.text) if hi_ else None
        if lm_:
            lc_idx_slots.add(lm_.group(1))
        bb_ = fn.blocks.get(f"lc_body_{lp_['id']}")
        st_ = next((SLOT_STORE_GEN_RE.match(i.text) for i in bb_.instrs if i.op == "store" and SLOT_STORE_GEN_RE.match(i.text)), None) if bb_ else None
        if st_:
            lc_var_name[st_.group(2)] = f"lcv{lp_['id']}"
    all_i = [x for l_ in fn.block_order for x in fn.blocks[l_].instrs]
    d0 = {x.result: x for x in all_i if x.result}
    old_rel = set()                    # reading a cell's old value just to release it (a[i][j] = obj): compiler plumbing, not in the source
    for x in all_i:
        gm_ = CALL_RE.match(x.text) if x.op == "call" else None
        if not gm_ or gm_.group(2) != "mocha_array_get":
            continue
        at_ = [a.split()[-1] for a in split_top_level(gm_.group(3))]
        rd_ = d0.get(at_[0])
        rm_ = CALL_RE.match(rd_.text) if rd_ is not None and rd_.op == "call" else None
        bd_ = d0.get(at_[2])
        bm_ = BITCAST_RE.match(bd_.text) if bd_ is not None else None
        if not rm_ or rm_.group(2) != "mocha_array2d_get_row" or not bm_:
            continue
        lds_ = [y for y in all_i if y.op == "load" and y.text.endswith("* " + bm_.group(2))]
        if len(lds_) != 1:
            continue
        users_ = [y for y in all_i if y is not lds_[0] and lds_[0].result in TEMP_RE.findall(y.text)]
        assert rd_ is not None
        rusers_ = [y for y in all_i if y is not rd_ and y is not x and rd_.result in TEMP_RE.findall(y.text)]
        if all(y.op == "call" and CALL_RE.match(y.text) and CALL_RE.match(y.text).group(2).endswith("_release") for y in users_ + rusers_): # type: ignore
            old_rel.add(id(x))
            old_rel.add(id(rd_))
    got, slot_val, lit_elems, bc_from, stored_to = {}, {}, {}, {}, {}
    dead_slots = set()                             # a %MochaArray* temp slot that only gets one store of a call result and is never read
    for x_ in all_i:
        if x_.op == "alloca" and x_.result and x_.result.startswith("%t") and x_.text.strip() in ("alloca %MochaArray*", "alloca %MochaArray2D*"):
            refs_ = [y_ for y_ in all_i if y_ is not x_ and re.search(re.escape(x_.result) + r'(?![\w.$])', y_.text)]
            if len(refs_) == 1 and refs_[0].op == "store":
                sm_ = SLOT_STORE_GEN_RE.match(refs_[0].text)
                sd_ = d0.get(sm_.group(1)) if sm_ else None
                if sd_ is not None and sd_.op == "call":
                    dead_slots.add(x_.result)
    pnames = {n for _, n in fn.params}
    colls = infer_collections(fn)
    for label in fn.block_order:
        for i in fn.blocks[label].instrs:
            if i.result:
                defs[i.result] = i
            cm_ = CALL_RE.match(i.text) if i.op == "call" else None
            if id(i) in old_rel:
                continue                      # old-value read before an overwrite: not a use
            dsm_ = SLOT_STORE_GEN_RE.match(i.text) if i.op == "store" else None
            if dsm_ and dsm_.group(2) in dead_slots:
                continue                      # a store into a never-read array slot: not a use of the call result
            if cm_ and (PLUMBING_RE.match(cm_.group(2)) or cm_.group(2) == "mocha_array_init_set"):
                continue                      # releases and array-literal fills are not uses of the value
            if cm_ and cm_.group(2) == "mocha_array2d_set" and cm_.group(3).split()[1].rstrip(",") in lit2_tmp:
                continue                      # filling a 2D array literal
            if cm_ and (cm_.group(2) in ("mocha_set_insert", "mocha_tuple_set") or DICT_SET_RE.match(cm_.group(2))) \
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
    for x in all_i:                    # a closure bundle: the bitcast that fills slot 0 is plumbing, not a use of the bundle
        bm_ = BITCAST_RE.match(x.text) if x.op == "bitcast" else None
        sd_ = d0.get(bm_.group(2)) if bm_ else None
        if bm_ and bm_.group(1) == "i8*" and bm_.group(3) == "i8**" and sd_ is not None and "@malloc(i64 24)" in sd_.text:
            uses[bm_.group(2)] = uses.get(bm_.group(2), 0) - 1
    try_site = {}
    for tr_ in find_trys(fn):
        try_site[tr_["site"]] = tr_
    match_first = {}                   # first test block of each match -> its description
    for mt_ in find_matches(fn):
        if not mt_["cases"] or not mt_["end"]:
            raise EmitError(f"{fn.name}: a match I can't read (no cases or no end block)")
        sc_ = mt_["cases"][0]["scrutinee"]
        if sc_ is None:                            # a string match: the subject is the first operand of mocha_str_eq
            for i_ in fn.blocks[mt_["cases"][0]["test_block"]].instrs:
                c_ = CALL_RE.match(i_.text) if i_.op == "call" else None
                if c_ and c_.group(2) == "mocha_str_eq":
                    sc_ = [a.split()[-1] for a in split_top_level(c_.group(3))][0]
                    mt_["str_match"] = True
            if sc_ is None:
                raise EmitError(f"{fn.name}: a match I can't read (no subject)")
            mt_["cases"][0]["scrutinee"] = sc_
        bd_ = d0.get(sc_)                          # guarded match: the "subject" is a load of the case's own binding, the real subject is what was stored into it
        bb_ = re.match(r'^load \S+, \S+\* (%match_bind_\w+)\s*$', bd_.text) if bd_ is not None else None
        if bb_:
            for x_ in all_i:
                st_ = re.fullmatch(r'store \S+ (\S+), \S+\* ' + re.escape(bb_.group(1)), x_.text) if x_.op == "store" else None
                if st_:
                    sc_ = st_.group(1)
                    mt_["cases"][0]["scrutinee"] = sc_
                    break
        match_first[mt_["cases"][0]["test_block"]] = mt_
        uses[sc_] = min(uses.get(sc_, 1), 1)       # compared once per case in the IR: still one source use

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
        if m and m.group(1) == "%MochaArray*" and m.group(3).startswith("%struct."):
            once(t, d)
            rt_, _ = operand(m.group(2))
            return rt_ + "[]", 9                   # t[0][] gives a row that the compiler casts to the class: the [] is what marks it in the source
        if m and m.group(1) == m.group(3) == "double":
            once(t, d)
            return operand(m.group(2))             # float(x): an explicit cast to the same type, invisible in the IR
        if m and m.group(3).startswith("%struct.") and (m.group(1).startswith("%struct.") or m.group(1) == "i8*"):
            return operand(m.group(2))             # upcast to a parent class: invisible in the source
        if m and m.group(1) == "i8**" and m.group(3).startswith("%struct."):
            gd_ = defs.get(m.group(2))
            gm_ = re.match(r'^getelementptr inbounds %struct\.\w+, %struct\.\w+\* (%[\w.$]+), i32 0, i32 \d+$', gd_.text) if gd_ is not None else None
            if gm_:
                return operand(gm_.group(1))       # a multiple-inheritance upcast: the parent sub-object is the object itself in the source
        if m and m.group(1) == "i8*" and m.group(3) == "%MochaClosureBundle*":
            return operand(m.group(2))             # a closure handed to a runtime call: invisible in the source
        if m and m.group(1) == "i8*" and m.group(3) in COLL_SUFFIX:
            return operand(m.group(2))             # a raw value read back as a collection (nested dict): invisible in the source
        if m and m.group(3) == "i8*" and (m.group(1).startswith("%struct.") or m.group(1) in COLL_SUFFIX):
            return operand(m.group(2))             # an object stored into a collection as a raw pointer: invisible in the source
        cn_ = re.search(r';\s*const (\w+)\s*$', d.raw)
        if cn_ and (LIT_INT_RE.match(d.text) or LIT_FLT_RE.match(d.text)):
            return cn_.group(1), 9             # a named constant: the compiler left '; const NAME' on the literal
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
        bm_ = re.match(r'^load \S+, \S+\* %match_bind_(\w+)_\d+_\d+\s*$', d.text)
        if bm_:
            return bm_.group(1), 9                 # a guarded case reading its own binding
        m = LOAD_RE.match(d.text)
        if m:
            nm_ = var_name(m.group(3))
            lv_ = re.fullmatch(r'lc_(\w+?)_\d+', nm_)      # a comprehension's loop variable: lc_u_31 is 'u' in the source
            if nm_.startswith("captured_"):
                nm_ = nm_[len("captured_"):]       # a lambda's captured variable: the body copies it into captured_NAME
            return (lv_.group(1) if lv_ else nm_), 9
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
        if m and m.group(1) in lc_var_name:    # the comprehension's loop variable
            return lc_var_name[m.group(1)], 9
        if m and m.group(1) in lc_text:        # a finished list comprehension
            once(t, d)
            return lc_text[m.group(1)], 9
        if m and m.group(1) in got:
            once(t, d)
            return got[m.group(1)], 9
        if m and m.group(1) in fld:
            once(t, d)
            obj, fname = fld[m.group(1)]
            return f"{value(obj)}.{fname}", 9
        if m and m.group(1) in slot_val:       # a temp slot written by a store: loading it gives back that value
            once(t, d)
            return operand(slot_val[m.group(1)])
        if m:                                  # a load through a bitcast of a tuple_get result: t#0
            pd = defs.get(m.group(1))
            bm2 = BITCAST_RE.match(pd.text) if pd is not None else None
            sd2 = defs.get(bm2.group(2)) if bm2 and bm2.group(1) == "i8*" else None
            tm2 = CALL_RE.match(sd2.text) if sd2 is not None and sd2.op == "call" else None
            if tm2 and tm2.group(2) == "mocha_tuple_get":
                once(t, d)
                assert bm2 is not None
                return operand(bm2.group(2))
            if tm2 and tm2.group(2) == "mocha_dict_get_typed":     # d["k"] for int/float values: the result comes back as i8*, bitcast, then loaded
                once(t, d)
                assert bm2 is not None
                return operand(bm2.group(2))
        bl_ = re.match(r'^load i8, i8\* (%[\w.$]+)\s*$', d.text)
        bd_ = defs.get(bl_.group(1)) if bl_ else None
        bc_ = CALL_RE.match(bd_.text) if bd_ is not None and bd_.op == "call" else None
        if bc_ and bc_.group(2) == "mocha_dict_get_typed":     # d["k"] for a bool value: loaded straight from the returned i8*
            once(t, d)
            assert bl_ is not None
            return operand(bl_.group(1))
        m = ZEXT_RE.match(d.text) or CAST_RE.match(d.text)
        if m:
            once(t, d)
            return operand(m.group(1))
        m = BIN_RE.match(d.text)
        if m:
            once(t, d)
            op, _, a, b = m.groups()
            sym, p = BIN_OPS[op]
            if op == "xor" and _ == "i8" and ilit(b) == 1:     # !a compiles to a bool xor 1
                inner, pi = operand(a)
                return (f"!({inner})" if pi < 9 else f"!{inner}"), 3
            if op == "xor" and b == "-1":      # ~a compiles to a ^ -1
                inner, pi = operand(a)
                return (f"~({inner})" if pi < 9 else f"~{inner}"), 3
            (la, pa), (lb, pb) = operand(a), operand(b)
            if op == "sub" and la == "0":      # unary minus compiles to 0 - x
                return (f"-({lb})" if pb < 9 or lb.startswith("-") else f"-{lb}"), 3
            if pa < p:
                la = f"({la})"
            if pb <= p or lb.startswith("-"):
                lb = f"({lb})"
            return f"{la} {sym} {lb}", p
        m = PCMP_RE.match(d.text)
        if m:
            once(t, d)
            la, pa = operand(m.group(3))
            if pa <= 0:
                la = f"({la})"
            return f"{la} {CMP_OPS[m.group(1)]} null", 0
        m = CMP_RE.match(d.text)
        if m and ilit(m.group(4)) == 0:
            sd = defs.get(m.group(3))
            sq = CALL_RE.match(sd.text) if sd is not None and sd.op == "call" else None
            if sq and sq.group(2) == "strcmp":      # a > b on strings compiles to strcmp(a, b) > 0
                once(t, d)
                once(m.group(3), sd)
                sa = [x.split()[-1] for x in split_top_level(sq.group(3))]
                (la, pa), (lb, pb) = operand(sa[0]), operand(sa[1])
                if pa <= 0:
                    la = f"({la})"
                if pb <= 0:
                    lb = f"({lb})"
                return f"{la} {CMP_OPS[m.group(1)]} {lb}", 0
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
        m = FPTOSI_RE.match(d.text)
        if m:
            once(t, d)
            return f"int({value(m.group(1))})", 9
        m = FNEG_RE.match(d.text)
        if m:
            once(t, d)
            inner, pi = operand(m.group(1))
            return (f"-({inner})" if pi < 9 else f"-{inner}"), 3
        if d.op == "call":
            cm = CALL_RE.match(d.text)
            if cm and cm.group(2) in COMPLEX_OPS:
                once(t, d)
                ctoks = [a.split()[-1] for a in split_top_level(cm.group(3))]
                sym, p = COMPLEX_OPS[cm.group(2)]
                (la, pa), (lb, pb) = cx_operand(ctoks[0]), cx_operand(ctoks[1])
                lit_ = [defs.get(x) for x in ctoks]
                if not any(d_ is not None and d_.op == "call" and "mocha_complex_new" in d_.text for d_ in lit_) \
                        and not any(x.startswith("%") and re.search(r'\bim$', cx_operand(x)[0]) for x in ctoks):
                    la_, pla_ = operand(ctoks[0])
                    if pla_ < 9:
                        la_ = f"({la_})"           # (x + 0im).sub(...): an operator expression needs parentheses before a method call
                    return f"{la_}.{METHOD_BUILTINS[cm.group(2)]}({value(ctoks[1])})", 9
                if pa < p:
                    la = f"({la})"
                if pb <= p:
                    lb = f"({lb})"
                return f"{la} {sym} {lb}", p
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

    def cx_operand(tok):
        """-> (text, precedence) for one operand of complex arithmetic: 2 / 3im instead of Complex(...)."""
        d = defs.get(tok)
        cm = CALL_RE.match(d.text) if d is not None and d.op == "call" else None
        if cm and cm.group(2) == "mocha_complex_new":
            a = [x.split()[-1] for x in split_top_level(cm.group(3))]
            if a[0] == "0.0" and not a[1].startswith("%"):         # 3im: bare literal real, literal imag
                once(tok, d)
                v = float(a[1])
                return (str(int(v)) if v.is_integer() else fmt_float(v)) + "im", 9
            if a[1] == "0.0" and a[0].startswith("%"):             # a real scalar wrapped as Complex(x, 0)
                once(tok, d)
                return operand(a[0])
        return operand(tok)

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
        im_ = INDIRECT_RE.match(d.text)
        if im_:                                # calling a lambda parameter: pred(x). Slot 0 of the bundle is the function, slot 1 the env (last argument, not in the source)
            fpd_ = defs.get(im_.group(2))
            fcm_ = FNPTR_CAST_RE.match(fpd_.text) if fpd_ is not None else None
            fld_ = defs.get(fcm_.group(1)) if fcm_ else None
            fsm_ = SLOT_ANY_LOAD_RE.match(fld_.text) if fld_ is not None and fld_.op == "load" else None
            fbd_ = defs.get(fsm_.group(1)) if fsm_ else None
            fbm_ = BITCAST_RE.match(fbd_.text) if fbd_ is not None and fbd_.op == "bitcast" else None
            if not fbm_ or fbm_.group(1) != "i8*":
                raise EmitError(f"{fn.name}: an indirect call whose function I can't trace")
            target_ = value(fbm_.group(2))
            iargs_ = []
            for t_ in [a.split()[-1] for a in split_top_level(im_.group(3))][:-1]:
                s_ = slot_for(t_)
                iargs_.append(value(slot_val[s_]) if s_ is not None and s_ in slot_val else value(t_))
            return f"{target_}({', '.join(iargs_)})"
        callee, toks = parse_call(d)
        if callee == "mocha_str_literal":
            gd = defs.get(toks[0])
            gm = GEP_STR_RE.match(gd.text) if gd else None
            if not gm:
                raise EmitError(f"{fn.name}: string literal from an unknown source: {d.raw[:90]}")
            return quote(g.strings[gm.group(1)])
        if callee == "mocha_array2d_new":
            if ilit(toks[3]) != 1 and ilit(toks[0]) == 0 and ilit(toks[1]) == 0:
                return "[[]]"                  # an empty 2D array needs no element type
            if ilit(toks[3]) != 1 and not var_types.get(stored_to.get(d.result) or "", "").endswith("[][]"):
                fslot, fcls = None, None       # an alloc stored into a class field: the old value's release_objs names the element class
                for lbl in fn.block_order:
                    for x in fn.blocks[lbl].instrs:
                        sm_ = SLOT_STORE_GEN_RE.match(x.text) if x.op == "store" else None
                        if sm_ and sm_.group(1) == d.result and sm_.group(2) in fld:
                            fslot = sm_.group(2)
                if fslot:
                    for lbl in fn.block_order:
                        for x in fn.blocks[lbl].instrs:
                            rm_ = CALL_RE.match(x.text) if x.op == "call" else None
                            if rm_ and rm_.group(2) == "mocha_array2d_release_objs":
                                ld_ = defs.get(rm_.group(3).split()[1].rstrip(","))
                                lm_ = SLOT_ANY_LOAD_RE.match(ld_.text) if ld_ is not None else None
                                cm_ = re.search(r'@(\w+)_release to', rm_.group(3))
                                if lm_ and lm_.group(1) == fslot and cm_:
                                    fcls = cm_.group(1)
                if fcls:
                    return f"alloc {fcls}[{value(toks[0])}][{value(toks[1])}]"
                if fslot:                      # no element class in the IR: the module-wide field type (from the creation args) gives it
                    fgd_ = defs.get(fslot)
                    fgm_ = GEP_FIELD_RE.match(fgd_.text) if fgd_ is not None and fgd_.op == "getelementptr" else None
                    ffty_ = FIELD_TYPES.get((fgm_.group(1), fgm_.group(3))) if fgm_ else None
                    if ffty_ and ffty_.endswith("[][]"):
                        return f"alloc {ffty_[:-4]}[{value(toks[0])}][{value(toks[1])}]"
            ptr = stored_to.get(d.result)
            ty = var_types.get(ptr) if ptr else None
            if (not ty or not ty.endswith("[][]")) and ilit(toks[3]) != 1:
                raise EmitError(f"{fn.name}: can't tell the element type of a 2D array")
            if ilit(toks[3]) == 1:
                r, c, cells = ilit(toks[0]), ilit(toks[1]), lit2.get(d.result, {})
                if r is None or c is None or any((x, y) not in cells for x in range(r) for y in range(c)):
                    raise EmitError(f"{fn.name}: a 2D array literal I can't rebuild")
                return "[" + ", ".join("[" + ", ".join(cells[(x, y)] for y in range(c)) + "]" for x in range(r)) + "]"
            if ilit(toks[0]) == 0 and ilit(toks[1]) == 0:
                return "[[]]"
            return f"alloc {ty[:-4]}[{value(toks[0])}][{value(toks[1])}]"
        if callee == "mocha_array2d_from_rows":   # [[...] for each y in ys]: the rows array is the outer comprehension, the two ints are bookkeeping
            return value(toks[0])
        if callee == "mocha_array2d_rows":
            return f"{value(toks[0])}.length"
        if callee == "mocha_array2d_cols":
            return f"{value(toks[0])}.cols"
        if callee == "mocha_array2d_get_col":   # a[][k]
            return f"{value(toks[0])}[][{value(toks[1])}]"
        if callee == "mocha_array2d_get_row":
            return f"{value(toks[0])}[{value(toks[1])}]"
        if callee == "mocha_array2d_push_col":  # a.push(col_array, col=true)
            return f"{value(toks[0])}.push({value(toks[1])}, col=true)"
        if callee == "mocha_array2d_push_row":
            return f"{value(toks[0])}.push({value(toks[1])})"
        if callee == "mocha_file_open":
            return f"open({', '.join(value(t) for t in toks)})"
        if callee in METHOD_BUILTINS:
            return f"{value(toks[0])}.{METHOD_BUILTINS[callee]}({', '.join(value(t) for t in toks[1:])})"
        if callee in STR_METHODS:
            la, pa = operand(toks[0])
            return (f"({la})" if pa < 9 else la) + STR_METHODS[callee]
        if callee == "mocha_set_size":         # s.size: a property, like .length
            return f"{value(toks[0])}.size"
        om = re.match(r'^mocha_array(2d)?_occs(?:_(row|col)(range)?)?$', callee)
        if om:                                 # a.occs(x), g.occs(x, row=r), col=r, row=[a, b], col=[a, b]
            oslot = slot_for(toks[1])
            if oslot is None or oslot not in slot_val:
                raise EmitError(f"{fn.name}: an occs() whose value I can't trace")
            extra = ""
            if om.group(2):
                rest = [value(t) for t in toks[2:]]
                extra = f", {om.group(2)}=" + (f"[{', '.join(rest)}]" if om.group(3) else rest[0])
            return f"{value(toks[0])}.occs({value(slot_val[oslot])}{extra})"
        if callee == "malloc":                 # a closure bundle: slot 0 holds the lambda's function pointer
            fp_ = None
            for x in all_i:
                bm_ = BITCAST_RE.match(x.text) if x.op == "bitcast" else None
                if bm_ and bm_.group(2) == d.result and bm_.group(3) == "i8**":
                    for y in all_i:
                        st_ = re.fullmatch(r'store i8\* (%[\w.$]+), i8\*\* ' + re.escape(x.result), y.text) if y.op == "store" else None
                        if st_:
                            fp_ = st_.group(1)
            fd_ = defs.get(fp_) if fp_ else None
            lm_ = re.search(r'@(mocha_lambda_\d+) to i8\*', fd_.text) if fd_ is not None else None
            if not lm_ or lm_.group(1) not in MODULE_FUNCS:
                raise EmitError(f"{fn.name}: a malloc I can't read as a closure")
            return lambda_text(MODULE_FUNCS[lm_.group(1)], g)
        if callee in ("mocha_math_derivative", "mocha_math_limit"):  # (2.0).derivative(lambda ...), (2.0).limit(lambda ...)
            r_, pr_ = operand(toks[0])
            if pr_ < 9 or r_[:1] in '"-0123456789':
                r_ = f"({r_})"
            return f"{r_}.{callee[len('mocha_math_'):]}({value(toks[1])})"
        if callee in ("mocha_sort_int", "mocha_sort_float", "mocha_sort_str", "mocha_sort_bool", "mocha_sort_vast"):   # a.sort()
            return f"{value(toks[0])}.sort()"
        if callee in ("mocha_sort_int_cmp_env", "mocha_sort_float_cmp_env", "mocha_sort_str_cmp_env"): # sort(nums, lambda ...)
            return f"sort({value(toks[0])}, {value(toks[1])})"
        if callee == "mocha_complex_conjugate":  # z.conjugate()
            return f"{value(toks[0])}.conjugate()"
        if callee == "mocha_file_exists":      # exists("path"): a free function, returns bool
            return f"exists({value(toks[0])})"
        mm = re.match(r'^mocha_(?:array|set)_(min|max)_(?:int|float|str|vast)$', callee)
        if mm:                                 # a.min() / a.max(): the type suffix is only the compiler's variant
            return f"{value(toks[0])}.{mm.group(1)}()"
        if callee == "mocha_set_retype":       # s.retype(float): the second argument is the SET_CODE of the new element type
            code = ilit(toks[1])
            if code not in SET_CODE:
                raise EmitError(f"{fn.name}: a set retype to the unknown type code {toks[1]}")
            return f"{value(toks[0])}.retype({SET_CODE[code]})"
        if callee == "mocha_set_clean":        # s.clean()
            return f"{value(toks[0])}.clean()"
        if callee == "mocha_set_negate":       # s.negate()
            return f"{value(toks[0])}.negate()"
        if callee == "mocha_array2d_resize":   # g.resize(rows, cols): the last argument is the element size
            return f"{value(toks[0])}.resize({value(toks[1])}, {value(toks[2])})"
        if callee in ("mocha_array2d_drop_row", "mocha_array2d_drop_row_objs"): # a.drop(row=r); the _objs variant also passes a release function
            return f"{value(toks[0])}.drop(row={value(toks[1])})"
        if callee in ("mocha_array2d_drop_col", "mocha_array2d_drop_col_objs"): # a.drop(col=c)
            return f"{value(toks[0])}.drop(col={value(toks[1])})"
        if callee == "mocha_dict_jsonify":     # d.jsonify()
            return f"{value(toks[0])}.jsonify()"
        if callee == "mocha_dict_allkeys":     # d.allKeys()
            return f"{value(toks[0])}.allKeys()"
        if callee == "mocha_dict_allvalues":   # d.allValues()
            return f"{value(toks[0])}.allValues()"
        if callee == "mocha_set_subset":       # a.subset(b); b.superset(a) compiles to the same call
            return f"{value(toks[0])}.subset({value(toks[1])})"
        if callee == "mocha_set_jaccard":      # a.jaccard(b)
            return f"{value(toks[0])}.jaccard({value(toks[1])})"
        if callee == "mocha_set_rel_diff":     # a.rel_diff(b)
            return f"{value(toks[0])}.rel_diff({value(toks[1])})"
        if callee == "mocha_set_intersect":    # a.intersect(b)
            return f"{value(toks[0])}.intersect({value(toks[1])})"
        if callee == "mocha_set_xor":          # a.xor(b)
            return f"{value(toks[0])}.xor({value(toks[1])})"
        if callee == "mocha_set_union":        # a.union(b)
            return f"{value(toks[0])}.union({value(toks[1])})"
        if callee in ("mocha_dict_copy", "mocha_array_copy"):        # a.copy()
            return f"{value(toks[0])}.copy()"
        if callee == "mocha_dict_merge":       # a.merge(b); the last argument is the override flag
            ov = ", override=true" if toks[2] not in ("0", "false") else ""
            return f"{value(toks[0])}.merge({value(toks[1])}{ov})"
        if callee == "mocha_dict_has":         # d.has("k"): the key is a plain string
            return f"{value(toks[0])}.has({value(toks[1])})"
        if callee == "mocha_set_has":          # s.has(x): the value sits in a malloc'd slot
            hslot = slot_for(toks[1])
            if hslot is None or hslot not in slot_val:
                raise EmitError(f"{fn.name}: a set has() whose value I can't trace")
            return f"{value(toks[0])}.has({value(slot_val[hslot])})"
        if callee == "mocha_dict_get_typed":   # d["k"]: the last argument is a type tag, not in the source
            return f"{value(toks[0])}[{value(toks[1])}]"
        if callee == "mocha_dict_get":         # d["k"]
            return f"{value(toks[0])}[{value(toks[1])}]"
        if callee == "mocha_tuple_get":
            return f"{value(toks[0])}#{value(toks[1])}"
        if callee == "mocha_str_format":       # "n=$0".format(n): args sit in a stack array, each wrapped in a to-string call
            slots = {}
            for x in defs.values():
                gm2 = re.match(r'^getelementptr i8\*, i8\*\* (%[\w.$]+), i32 (\d+)$', x.text)
                if gm2 and gm2.group(1) == toks[1]:
                    slots[int(gm2.group(2))] = x.result
            fargs = []
            for k in range(int(toks[2])):
                tv = slot_val.get(slots.get(k))
                if tv is None:
                    raise EmitError(f"{fn.name}: a format argument I can't trace")
                td = defs.get(tv)
                tc = CALL_RE.match(td.text) if td is not None and td.op == "call" else None
                if tc and tc.group(2) in TO_STR:
                    tv = [a.split()[-1] for a in split_top_level(tc.group(3))][0]
                fargs.append(value(tv))
            return f"{value(toks[0])}.format({', '.join(fargs)})"
        if callee == "mocha_str_format_named":  # "$nm".format(nm="x"): keys and values sit in two stack arrays
            def slots_of(base):
                out = {}
                for x in defs.values():
                    g2 = re.match(r'^getelementptr i8\*, i8\*\* (%[\w.$]+), i32 (\d+)$', x.text)
                    if g2 and g2.group(1) == base:
                        out[int(g2.group(2))] = x.result
                return out
            ks, vs = slots_of(toks[1]), slots_of(toks[2])
            parts = []
            for k in range(int(toks[3])):
                kt, vt = slot_val.get(ks.get(k)), slot_val.get(vs.get(k))
                if kt is None or vt is None:
                    raise EmitError(f"{fn.name}: a named format argument I can't trace")
                kd = defs.get(kt)
                km = GEP_STR_RE.match(kd.text) if kd is not None else None
                if not km:
                    raise EmitError(f"{fn.name}: a format key that isn't a string constant")
                vd = defs.get(vt)
                vc = CALL_RE.match(vd.text) if vd is not None and vd.op == "call" else None
                if vc and (vc.group(2) in TO_STR or vc.group(2) == "mocha_vast_to_str"):
                    vt = [a.split()[-1] for a in split_top_level(vc.group(3))][0]
                parts.append(f"{g.strings[km.group(1)]}={value(vt)}")
            return f"{value(toks[0])}.format({', '.join(parts)})"
        if callee == "mocha_tuple_new":
            te, tn = lit_elems.get(d.result), ilit(toks[0])
            if not te or tn is None or len(te) != tn:
                raise EmitError(f"{fn.name}: a tuple literal I can't rebuild")
            return "(" + ", ".join(te[k] for k in range(tn)) + ")"
        if callee == "mocha_set_new":
            e = lit_elems.get(d.result)
            return ("<" + ", ".join(e[k] for k in sorted(e)) + ">") if e else "<>"
        if callee == "mocha_dict_new":
            e = lit_elems.get(d.result)
            return ("{" + ", ".join(e[k] for k in sorted(e)) + "}") if e else "{}"
        if callee == "mocha_sb_new":           # StringBuilder()
            return "StringBuilder()"
        if callee == "mocha_ht_new":           # HashTable()
            return "HashTable()"
        if callee == "mocha_complex_new":
            return f"Complex({value(toks[0])}, {value(toks[1])})"
        em_ext = EXT_RE.match(callee)
        if em_ext:
            r, pr = operand(toks[0])
            if pr < 9 or r[:1] in '"-0123456789':
                r = f"({r})"                   # ("12345").regex_full(...) is how the source writes it
            return f"{r}.{em_ext.group(1)}({', '.join(value(t) for t in toks[1:])})"
        if callee in ("mocha_array_length", "mocha_dict_length"):
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
            if not ty:                         # an alloc stored into a class field: a typed local copied from the same field gives the element type
                fslot = next((x_.group(2) for x_ in (SLOT_STORE_GEN_RE.match(y.text) for y in defs.values() if False) if x_), None)
                for lbl in fn.block_order:
                    for x in fn.blocks[lbl].instrs:
                        sm_ = SLOT_STORE_GEN_RE.match(x.text) if x.op == "store" else None
                        if sm_ and sm_.group(1) == d.result and sm_.group(2) in fld:
                            fslot = sm_.group(2)
                if fslot:
                    fname_ = fld[fslot][1]
                    fty = set()
                    for lbl in fn.block_order:
                        for x in fn.blocks[lbl].instrs:
                            sm_ = STORE_RE.match(x.text) if x.op == "store" else None
                            if not sm_ or sm_.group(4) not in var_types or not var_types[sm_.group(4)].endswith("[]"):
                                continue
                            ld_ = defs.get(sm_.group(2))
                            lm_ = SLOT_ANY_LOAD_RE.match(ld_.text) if ld_ is not None else None
                            if lm_ and lm_.group(1) in fld and fld[lm_.group(1)][1] == fname_:
                                fty.add(var_types[sm_.group(4)])
                    if len(fty) == 1:
                        return f"alloc {next(iter(fty))[:-2]}[{value(toks[0])}]"
                    if not fty and ilit(toks[1]) == 8:      # no typed evidence: the release flag on the field's old value is 0 for float/vast (1 is str); float is the default, vast is indistinguishable in the IR
                        for lbl in fn.block_order:
                            for x in fn.blocks[lbl].instrs:
                                rm_ = CALL_RE.match(x.text) if x.op == "call" else None
                                if not rm_ or rm_.group(2) != "mocha_array_release":
                                    continue
                                ra_ = split_top_level(rm_.group(3))
                                ld_ = defs.get(ra_[0].split()[-1])
                                lm_ = SLOT_ANY_LOAD_RE.match(ld_.text) if ld_ is not None else None
                                if lm_ and lm_.group(1) == fslot and ra_[-1].split()[-1] == "0":
                                    return f"alloc float[{value(toks[0])}]"
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
        lm_one = re.fullmatch(r'mocha_lua_call(\d[ns]+)_(\w+)', callee)
        if lm_one:                             # lua_call_bool_1n(ls, "f", 5.0): the IR says call1n_bool, the source says call_bool_1n
            return f"lua_call_{lm_one.group(2)}_{lm_one.group(1)}({', '.join(value(t) for t in toks)})"
        if callee.startswith("mocha_lua_"):    # lua_begin_call(ls, "f"), lua_push_int(ls, 3)...: the source name is the callee without mocha_
            return f"{callee[len('mocha_'):]}({', '.join(value(t) for t in toks)})"
        if callee == "rc_weak_get":            # reading a weak field: the source just says this.parent
            return operand(toks[0])[0]
        cxm_ = re.match(r'^mocha_ext_Complex_(\w+)$', callee)
        if cxm_:                               # d.addition(3): an extension method on Complex, the first argument is the receiver
            r_, pr_ = operand(toks[0])
            if pr_ < 9:
                r_ = f"({r_})"
            return f"{r_}.{cxm_.group(1)}({', '.join(value(t) for t in toks[1:])})"
        if callee.startswith("mocha_tensor_"):  # the source calls these runtime functions by their IR name: mocha_tensor_softmax_grad(d.ptr, w.ptr)
            return f"{callee}({', '.join(value(t) for t in toks)})"
        if callee.startswith("mocha_"):
            raise EmitError(f"{fn.name}: no rule yet for the call to {callee}")
        ats = arg_types(d)
        if CLASSY_RE.match(callee) and "__" not in callee and toks:
            psd_ = defs.get(toks[0])
            psm_ = BITCAST_RE.match(psd_.text) if psd_ is not None else None
            if psm_ and psm_.group(1) == "i8**" and psm_.group(3) == f"%struct.{callee.split('_', 1)[0]}*":
                return f"{callee.split('_', 1)[0]}.{value(toks[0])}.{callee.split('_', 1)[1]}({', '.join(value(t) for t in toks[1:])})"   # a parent's method on a multiple-inheritance object: Horse.p.breathe()
        if ats and ats[0].startswith("%struct.") and ats[0].endswith("*"):
            cls = ats[0][len("%struct."):-1]
            if callee.startswith(cls + "_") and callee != cls + "_constructor":
                return f"{value(toks[0])}.{callee[len(cls) + 1:]}({', '.join(value(t) for t in toks[1:])})"
        if callee.endswith("__name") and callee[:-6] in g.tags and len(toks) == 1:   # s.name(): the compiler generates Status__name from the tag declaration
            la, pa = operand(toks[0])
            return (f"({la})" if pa < 9 else la) + ".name()"
        if ats and ats[0].startswith("%struct.") and ats[0].endswith("*") and CLASSY_RE.match(callee) \
                and not callee.startswith(ats[0][len("%struct."):-1] + "_") and "__" not in callee:
            parent, meth = callee.split("_", 1)    # Bird.p.breathe(): a parent's method chosen explicitly on a multiple-inheritance object
            return f"{parent}.{value(toks[0])}.{meth}({', '.join(value(t) for t in toks[1:])})"
        if CLASSY_RE.match(callee) and "__" not in callee and toks:
            sd_ = defs.get(toks[0])
            sm_ = BITCAST_RE.match(sd_.text) if sd_ is not None else None
            if sm_ and sm_.group(1) == "i8**" and sm_.group(3) == f"%struct.{callee.split('_', 1)[0]}*":
                return f"{callee.split('_', 1)[0]}.{value(toks[0])}.{callee.split('_', 1)[1]}({', '.join(value(t) for t in toks[1:])})"   # a parent's method on a multiple-inheritance object: Horse.p.breathe()
        if CLASSY_RE.match(callee) and "__" not in callee:
            cls_s, meth_s = callee.split("_", 1)      # shared method: Class.method(args), no this
            if f"%struct.{cls_s}" in "\n".join(str(x) for x in g.__dict__.values()) or callee in MODULE_FUNCS:
                return f"{cls_s}.{meth_s}({', '.join(value(t) for t in toks)})"
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
            ix_ = defs.get(toks[1])
            if lc_state["on"] and ix_ is not None and ("%lc_idx_" in ix_.text or any(ix_.text.endswith("* " + s_) for s_ in lc_idx_slots)):
                return                         # the comprehension reading its loop variable: not a source statement
            idx = f"[{value(toks[1])}][{value(toks[2])}]" if two else f"[{value(toks[1])}]"
            got[slot] = f"{value(toks[0])}{idx}"
            return
        if slot not in slot_val:
            raise EmitError(f"{fn.name}: {callee} stores a value I can't trace")
        val = value(slot_val[slot])
        if callee == "mocha_array_init_set":
            lit_elems.setdefault(toks[0], {})[int(toks[1])] = val
        elif lc_state["on"] and callee == "mocha_array_push":      # the comprehension's expression
            pm_ = SLOT_ANY_LOAD_RE.match(defs[toks[0]].text) if toks[0] in defs else None
            if not pm_:
                raise EmitError(f"{fn.name}: a comprehension push into something I can't trace")
            lc_state["expr"], lc_state["slot"] = val, pm_.group(1)
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
            if id(i) in old_rel:
                continue
            if i.op == "ret":
                rm = RET_VAL_RE.match(i.text)
                if rm:
                    entries.append((cur, "stmt", f"return {value(rm.group(2))};", ind))
                continue
            if i.op == "br" or i.op == "unreachable":
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
                    continue
                if "@RtlCaptureContext" in i.raw:
                    continue                   # the object is built where it is used: Class(args)
                if INDIRECT_RE.match(i.text):      # a closure call: printed where its result is used, or as a statement if nothing uses it
                    if not i.result or uses.get(i.result, 0) == 0:
                        entries.append((cur, "stmt", render_call(i) + ";", ind))
                    continue
                callee, toks = parse_call(i)
                if PLUMBING_RE.match(callee):
                    continue
                if callee in ARRAY_CALLS:
                    do_array(callee, toks, cur, ind)
                    continue
                if callee == "mocha_tuple_set" and toks[0] in lit_tmp and slot_for(toks[2]) is None \
                        and defs.get(toks[2]) is not None and defs[toks[2]].op == "call":
                    lit_elems.setdefault(toks[0], {})[ilit(toks[1])] = value(toks[2])   # a str element is passed directly, no slot
                    continue
                if callee == "mocha_tuple_set":        # building a tuple literal: (a, b)
                    tslot = slot_for(toks[2])
                    if tslot is None or tslot not in slot_val or toks[0] not in lit_tmp:
                        raise EmitError(f"{fn.name}: a tuple set I can't rebuild")
                    lit_elems.setdefault(toks[0], {})[ilit(toks[1])] = value(slot_val[tslot])
                    continue
                if callee == "mocha_ex_throw":         # rethrow;: the thrown value is the caught message
                    thd_ = defs.get(toks[0])
                    thm_ = SLOT_ANY_LOAD_RE.match(thd_.text) if thd_ is not None else None
                    thv_ = defs.get(slot_val.get(thm_.group(1))) if thm_ else None
                    if thv_ is not None and thv_.op == "call" and "@mocha_ex_pop" in thv_.text:
                        entries.append((cur, "stmt", "rethrow;", ind))
                        continue
                if callee == "mocha_ex_throw":         # fail "msg";
                    entries.append((cur, "stmt", f"fail {value(toks[0])};", ind))
                    continue
                if callee == "mocha_dict_remove":      # d.remove("k"): the key is a plain string, no value slot
                    entries.append((cur, "stmt", f"{value(toks[0])}.remove({value(toks[1])});", ind))
                    continue
                if callee == "mocha_set_delete":       # s.delete(x): the value sits in a malloc'd slot
                    dslot = slot_for(toks[1])
                    if dslot is None or dslot not in slot_val:
                        raise EmitError(f"{fn.name}: a set delete whose value I can't trace")
                    entries.append((cur, "stmt", f"{value(toks[0])}.delete({value(slot_val[dslot])});", ind))
                    continue
                if callee == "mocha_set_insert":
                    do_set(toks, cur, ind)
                    continue
                if DICT_SET_RE.match(callee):
                    do_dict(toks, cur, ind)
                    continue
                if callee == "mocha_array_set_str":     # g[r][c] = "text": the row comes from array2d_get_row, the value is passed directly
                    rd = defs.get(toks[0])
                    rc = CALL_RE.match(rd.text) if rd is not None and rd.op == "call" else None
                    if not rc or rc.group(2) != "mocha_array2d_get_row":
                        raise EmitError(f"{fn.name}: a str write into something other than a 2D array row")
                    rt = [a.split()[-1] for a in split_top_level(rc.group(3))]
                    entries.append((cur, "stmt", f"{value(rt[0])}[{value(rt[1])}][{value(toks[1])}] = {value(toks[2])};", ind))
                    continue
                if callee == "mocha_array_pop" and (toks[-1] == "null" or slot_for(toks[-1]) is not None):
                    entries.append((cur, "stmt", f"{value(toks[0])}.pop();", ind))
                    continue
                if callee == "mocha_dict_print_value":     # print(d["k"]): the compiler prints dict reads through this call
                    entries.append((cur, "print", (f"{value(toks[0])}[{value(toks[1])}]", toks[2]), ind))
                elif callee in ("mocha_array_print", "mocha_array2d_print", "mocha_tuple_print"):   # print(a) / print(t): the second argument is the element type code, the third the newline flag
                    entries.append((cur, "print", (value(toks[0]), toks[2]), ind))
                elif callee in ("mocha_dict_print", "mocha_print_complex"):         # print(d): the whole dict, second argument is the newline flag
                    entries.append((cur, "print", (value(toks[0]), toks[1]), ind))
                elif callee in PRINTS:
                    entries.append((cur, "print", (value(toks[0]), toks[1]), ind))
                elif i.result and uses.get(i.result, 0) == 0 and callee in (
                        "mocha_set_new", "mocha_dict_new", "mocha_array_new", "mocha_array2d_new", "mocha_dict_get"):
                    pass                       # an unused collection temp is compiler waste, not a statement
                elif not i.result or uses.get(i.result, 0) == 0:
                    entries.append((cur, "stmt", render_call(i) + ";", ind))
                continue
            if i.op == "store":
                if "%lc_idx_" in i.text:
                    continue                   # a comprehension's hidden counter
                sg_ = SLOT_STORE_GEN_RE.match(i.text)
                if sg_ and (sg_.group(2) in lc_idx_slots or sg_.group(2) in lc_var_name):
                    continue 
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
                if ptr.startswith("lc_"):
                    continue                   # a comprehension's loop variable is set up by the loop itself
                if m.group(2) == "null" and cur is None:
                    continue                   # prologue: pointer locals start out as null
                pd_ = defs.get(m.group(2))
                if pd_ is not None and pd_.op == "call" and "@mocha_ex_pop" in pd_.text:
                    declared.add(ptr)              # rescue, e: the caught message is bound by the rescue line itself
                    continue
                if m.group(2) in pnames:           # a parameter being copied into its own slot
                    declared.add(ptr)
                    continue
                ld_l = defs.get(m.group(2))
                lm_l = SLOT_ANY_LOAD_RE.match(ld_l.text) if ld_l is not None and ld_l.op == "load" else None
                src_l = defs.get(lm_l.group(1)) if lm_l else None
                if src_l is not None and (re.search(r'bitcast i8\* %\w+_raw to', src_l.text)
                                          or (src_l.op == "getelementptr" and "%env_" in src_l.text)):
                    declared.add(ptr)              # lambda plumbing: unboxing a param or copying a captured value into its local
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
                    am_ = re.match(r'(\w+)\[', rhs)
                    if ty == "int" and am_ and var_types.get(am_.group(1), "").endswith("[]") \
                        and var_types[am_.group(1)][:-2] in g.tags:
                        ty = var_types[am_.group(1)][:-2]   # an i32 read out of a tag array
                    sd = defs.get(m.group(2))
                    cm = CALL_RE.match(sd.text) if sd is not None and sd.op == "call" else None
                    if ty == "int" and cm and cm.group(2) in RET_MAP:
                        ty = RET_MAP[cm.group(2)]   # an i32 returned by a function declared -> Enum
                    if ty == "str" and rhs == "null":
                        ty = "null"                 # a literal null in an i8* local: no str is ever initialised to null in the corpus, so it's the opaque handle type
                    if ty == "str" and cm and (NATIVE_RET.get(cm.group(2)) == "null" or LIB_SIGS.get(cm.group(2)) == "null" or cm.group(2) == "fopen"):
                        ty = "null"                 # an opaque handle: the lib says -> null, the IR only says i8*
                    entries.append((cur, "stmt", f"var {name}: {ty} = {rhs};", ind))
                continue
            if (LIT_INT_RE.match(i.text) or LIT_FLT_RE.match(i.text) or GEP_STR_RE.match(i.text)
                    or i.op in ("load", "icmp", "fcmp", "trunc", "fneg", "zext", "sext", "sitofp", "fptosi", "getelementptr") or BIN_RE.match(i.text)):
                continue                  # printed where it is used
            raise EmitError(f"{fn.name}: unsupported instruction: {i.raw[:90]}")

    loop_stack = []                    # (header, end, continue-target) of the loops we are inside

    def settle(label, ind, skip=0):
        """Process a block; if it ends in an and/or branch, follow it to the block with the real branch."""
        process_block(label, ind, skip)
        if sc_right_blocks:
            for rb_ in sc_right_blocks:            # every and/or right side: record its array reads before the expression is rendered
                for i_ in fn.blocks[rb_].instrs:
                    cm_ = CALL_RE.match(i_.text) if i_.op == "call" else None
                    if cm_ and cm_.group(2) in ARRAY_CALLS and cm_.group(2).endswith("_get"):
                        tk_ = [a.split()[-1] for a in split_top_level(cm_.group(3))]
                        sl_ = slot_for(tk_[-1])
                        if sl_ is not None and sl_ not in got:
                            do_array(cm_.group(2), tk_, state["cur"], ind)
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
        is_set = fam == "foreach_set"
        step = f"foreach_set_step_{lid}" if is_set else f"foreach_step_{lid}"            # for each x in arr / <set>
        icm = next((i for i in fn.blocks[hdr].instrs if i.op == "icmp"), None)
        cmp_ = CMP_RE.match(icm.text) if icm else None
        bd = defs.get(cmp_.group(4)) if cmp_ else None
        bl = CALL_RE.match(bd.text) if bd is not None and bd.op == "call" else None
        if not bl or bl.group(2) != ("mocha_set_size" if is_set else "mocha_array_length"):
            raise EmitError(f"{fn.name}: a for-each over something other than an array or set (not supported yet)")
        arr_tok = bl.group(3).split()[-1]
        uses[arr_tok] = min(uses.get(arr_tok, 1), 1)       # read once for the length, once per element: still one source use
        body = fn.blocks[t_label].instrs
        k = next((j for j, i in enumerate(body) if i.op == "store" and STORE_RE.match(i.text)), None)
        if k is None:
            raise EmitError(f"{fn.name}: can't find the loop variable of a for-each")
        vptr = STORE_RE.match(body[k].text).group(4) # type: ignore
        declared.add(vptr)
        coll = f"<{value(arr_tok)}>" if is_set else value(arr_tok)
        return f"for each {var_name(vptr)} in {coll} {{", state["cur"], step, k + 1

    def emit_lc(lp, ind):
        """[expr for each x in arr] and [expr if cond for each x in arr]: nothing is printed here,
        the finished text waits in lc_text until the store at lc_end uses it."""
        info = describe_lc(fn, lp)
        info["var"] = info["var"] or lc_var_name.get(f"lcv{lp['id']}") or f"lcv{lp['id']}"
        if info["kind"] not in ("plain", "filtered", "ternary") or not info["var"]:
            raise EmitError(f"{fn.name}: a {info['kind']} list comprehension (not supported yet)")
        roles = info["roles"]
        icm = next((i for i in fn.blocks[lp["header"]].instrs if i.op == "icmp"), None)
        cmp_ = CMP_RE.match(icm.text) if icm else None
        bd = defs.get(cmp_.group(4)) if cmp_ else None
        bl = CALL_RE.match(bd.text) if bd is not None and bd.op == "call" else None
        if not bl or bl.group(2) != "mocha_array_length":
            raise EmitError(f"{fn.name}: a comprehension over something other than an array (not supported yet)")
        arr = value(bl.group(3).split()[-1])
        lc_state.update(on=True, expr=None, slot=None)
        try:
            body = roles["body"]
            inner = next((l2 for l2 in loops.values() if l2["family"] == "lc" and l2["id"] != lp["id"]
                          and l2["header"] in lp["body"]), None)
            if inner:                          # nested: finish the inner comprehension first, its text waits in lc_text
                outer_state = dict(lc_state)
                process_block(body, ind)
                saved = dict(lc_state)
                emit_lc(inner, ind)
                lc_state.update(on=True, expr=saved["expr"], slot=saved["slot"])
                process_block(inner["end"], ind)
            else:
                process_block(body, ind)
            cond = None
            if info["kind"] == "filtered":
                bm = BR_COND.match(fn.blocks[body].instrs[-1].text)
                if not bm:
                    raise EmitError(f"{fn.name}: {body} doesn't end in a conditional branch")
                cond = value(bm.group(1))
                process_block(roles["append"], ind)
            if info["kind"] == "ternary":          # A if cond else B: both branches store into one hidden slot, the merge block pushes it
                bm = BR_COND.match(fn.blocks[body].instrs[-1].text)
                if not bm or "merge" not in roles:
                    raise EmitError(f"{fn.name}: a ternary comprehension I can't read")
                tcond, parts, tslot = value(bm.group(1)), [], None
                for rl in ("then", "else"):
                    st = next((SLOT_STORE_GEN_RE.match(i.text) for i in fn.blocks[roles[rl]].instrs
                               if i.op == "store" and SLOT_STORE_GEN_RE.match(i.text)), None)
                    if st is None:
                        raise EmitError(f"{fn.name}: a ternary branch that stores nothing")
                    parts.append(value(st.group(1)))
                    tslot = st.group(2)
                got[tslot] = f"{parts[0]} if {tcond} else {parts[1]}"
                process_block(roles["merge"], ind)
            expr, slot = lc_state["expr"], lc_state["slot"]
        finally:
            lc_state["on"] = False
        if expr is None:
            raise EmitError(f"{fn.name}: can't find what this list comprehension collects (a nested one?)")
        lc_text[slot] = f"[{expr}{' if ' + cond if cond else ''} for each {info['var']} in {arr}]"
        return lp["end"]

    def emit_dowhile(lp, ind):
        """do { body } while (cond);  body and condition share one block that branches back to itself."""
        hdr = lp["header"]
        cb_, m = None, None                        # the block holding the loop's conditional branch
        for l_ in fn.block_order:
            bm_ = BR_COND.match(fn.blocks[l_].instrs[-1].text)
            if bm_ and bm_.group(2) == hdr and bm_.group(3) == lp["end"]:
                cb_, m = l_, bm_
        if m is None:
            raise EmitError(f"{fn.name}: a do-while whose branch I can't read")
        entries.append((state["cur"], "stmt", "do {", ind))
        loop_stack.append((hdr, lp["end"], hdr))
        saved_ = loops.pop(hdr, None)              # so emit_from walks the header as a plain block, not as a new loop
        try:
            if cb_ == hdr:
                process_block(hdr, ind + 1)
            else:
                emit_from(hdr, ind + 1, cb_)
                process_block(cb_, ind + 1)
        finally:
            loop_stack.pop()
            if saved_ is not None:
                loops[hdr] = saved_
        cond = value(m.group(1))
        if cb_ == hdr or not any(LINE_RE.search(i_.raw) for i_ in fn.blocks[cb_].instrs):
            cl_ = state["cur"] + 1 if state["cur"] is not None else None
        else:
            cl_ = state["cur"]                     # the condition block has its own line marker
        entries.append((cl_, "stmt", f"}} while ({cond});", ind))
        return lp["end"]

    def emit_loop(lp, ind):
        if lp["family"] == "lc":
            return emit_lc(lp, ind)
        if lp["family"] == "dowhile":
            return emit_dowhile(lp, ind)
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

    def emit_try(tr, ind):
        """try { ... } rescue { ... };  the handler setup in the site block is plumbing."""
        entries.append((state["cur"], "stmt", "try {", ind))
        emit_from(tr["try_block"], ind + 1, tr["after"])
        entries.append((None, "stmt", "} rescue, " + tr["binding"] + " {" if tr["binding"] else "} rescue {", ind))
        emit_from(tr["rescue_block"], ind + 1, tr["after"])
        entries.append((None, "stmt", "};", ind))
        return tr["after"]
    
    def emit_match(mt, ind):
        """match (x) { case (T.A): stmt; default: stmt; };  each case is glued to its single statement."""
        cases = mt["cases"]
        entries.append((state["cur"], "stmt", f"match ({value(cases[0]['scrutinee'])}) {{", ind))
        arms = []
        for c in cases:
            tb_ = fn.blocks[c["test_block"]].instrs
            ba_ = next((i.result for i in tb_ if i.op == "alloca" and (i.result or "").startswith("%match_bind_")), None)
            if ba_:                                # case v when guard:
                bn_ = re.match(r'%match_bind_(\w+)_\d+_\d+$', ba_)
                gm_ = BR_COND.match(tb_[-1].text)
                if not bn_ or not gm_:
                    raise EmitError(f"{fn.name}: a guarded match case I can't read")
                arms.append((c["body_block"], f"case {bn_.group(1)} when {value(gm_.group(1))}:"))
                continue
            ld = next((i for i in fn.blocks[c["test_block"]].instrs if GLOBAL_LOAD_RE.match(i.text)), None)
            if ld is not None:
                arms.append((c["body_block"], f"case ({value(ld.result)}):"))
                continue
            ic_ = next((CMP_RE.match(i.text) for i in fn.blocks[c["test_block"]].instrs
                        if i.op == "icmp" and CMP_RE.match(i.text) and CMP_RE.match(i.text).group(1) == "eq"), None)
            il_ = ilit(ic_.group(4)) if ic_ else None
            if il_ is not None:
                arms.append((c["body_block"], f"case {il_}:"))     # case 0: an integer literal compared with the subject
                continue
            se = next((CALL_RE.match(i.text) for i in fn.blocks[c["test_block"]].instrs
                       if i.op == "call" and "@mocha_str_eq" in i.text), None)
            if se is None:
                raise EmitError(f"{fn.name}: a match case that is neither a tag nor a string (not supported yet)")
            lit = [a.split()[-1] for a in split_top_level(se.group(3))][1]
            arms.append((c["body_block"], f"case {value(lit)}:"))
        if mt["default"]:
            arms.append((mt["default"], "default:"))
        for body, head in arms:
            mark = len(entries)
            emit_from(body, ind + 1, mt["end"])
            if len(entries) - mark == 0:
                raise EmitError(f"{fn.name}: a match case with no statements")
            line, kind, text, lind = entries[mark]
            if len(entries) - mark == 1 and kind == "stmt":
                entries[mark] = (line, kind, head + " " + text, lind)       # case X: stmt;  on one line
            else:                                                            # several statements: the header gets its own line, just above the first one
                entries.insert(mark, (line - 1 if line is not None else None, "stmt", head, lind))
        entries.append((None, "stmt", "};", ind))
        return mt["end"]
    def emit_from(label, ind, stop, skip=0):
        steps = 0
        while label is not None and label != stop:
            steps += 1
            if steps > len(fn.block_order) + 5:
                raise EmitError(f"{fn.name}: walking the blocks never reached {stop or 'a return'}")
            if label != fn.block_order[0] and label not in has_pred:
                return                 # unreachable: both branches of an if/else already returned
            if label in match_first:
                label = emit_match(match_first[label], ind)
                continue
            if label in loops:
                label = emit_loop(loops[label], ind)
                continue
            if label in ifs:
                label = emit_if(ifs[label], ind, skip)
                skip = 0
                continue
            process_block(label, ind, skip)
            skip = 0
            if label in try_site:
                label = emit_try(try_site[label], ind)
                continue
            if label in sc_branch:             # and/or: the right side is rendered inside the expression
                label = sc_branch[label]
                continue
            term = fn.blocks[label].instrs[-1]
            if term.op == "unreachable":
                return                     # a block that ends in a throw: the walk stops here
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


def lambda_text(lam, g):
    """A lambda body as source text: lambda (a: int, b: int) -> bool: expr"""
    ids = [i for l in lam.block_order for i in lam.blocks[l].instrs]
    parts = []
    for ptype, pname in lam.params:
        pname = pname.lstrip('%')
        if ptype.startswith("%env_") or pname == "env_unused":
            continue
        ty = None
        for i in ids:
            m = BITCAST_RE.match(i.text) if i.op == "bitcast" else None
            if m and m.group(2) == "%" + pname and m.group(3).endswith("*"):
                ty = mocha_type(m.group(3)[:-1])
        if ty is None:
            raise EmitError(f"{lam.name}: can't tell the type of the lambda parameter '{pname}'")
        parts.append(f"{re.sub(r'_raw$', '', pname)}: {ty}")
    body = emit_function(lam, g)
    if len(body) != 1 or not body[0][1].strip().startswith("return "):
        raise EmitError(f"{lam.name}: a lambda body that isn't a single expression (not supported yet)")
    expr = body[0][1].strip()[len("return "):-1]
    return f"lambda ({', '.join(parts)}) -> {mocha_type(lam.ret_type)}: {expr}"


emit_straight = emit_function             # old name, still used by the runner

# ---------------------------------------------------------------- checking helpers
FLOAT_TOKEN = re.compile(r'(?<![\w.])(\d+\.\d*(?:[eE][-+]?\d+)?|\d+[eE][-+]?\d+)(?![\w.])')

def norm(s: str) -> str:
    s = re.sub(r'//.*$', '', s)
    if '[' in s:                               # comprehension variable names are not in the IR: compare them by position
        names_ = []
        for m_ in re.finditer(r'(?<=\s)for each (\w+) in\b', s):
            if '[' in s[:m_.start()] and m_.group(1) not in names_:
                names_.append(m_.group(1))
        for k_, nm_ in enumerate(names_):
            s = re.sub(r'\b' + nm_ + r'\b', f'_lcv{k_}', s)
    s = re.sub(r'(?<=\d)_(?=\d)', '', s)      # 10_000 -> 10000
    s = re.sub(r'\s+', '', s)
    s = re.sub(r'(\w+)\+\+', r'\1=\1+1', s)   # i++ and i = i + 1 are the same IR
    s = re.sub(r'(\w+)--', r'\1=\1-1', s)
    s = re.sub(r'([+\-])\(([\w.\[\]]+(?:[*/%][\w.\[\]]+)+)\)(?=[+\-;)]|$)', r'\1\2', s)   # a + (b*c) and a + b*c are the same IR
    s = re.sub(r'\b(\w+)\.superset\((\w+)\)', r'\2.subset(\1)', s)   # the compiler swaps the operands: b.superset(a) is a.subset(b)
    s = re.sub(r'^([\w.\[\]]+)([-+*/%])=(?!=)([\w.]+);$', r'\1=\1\2\3;', s)   # a += b and a = a + b are the same IR (plain right side only)
    s = re.sub(r'\bcase\(([\w.]+)\):', r'case\1:', s)   # case (T.A): and case T.A: are the same IR
    s = re.sub(r':set<(\w+)>', r':<\1>', s)            # var b: <int> and var b: set<int> are the same IR
    s = s.replace(',newLine=false', '')  # print(x) and print(x, newLine=false) are the same IR
    s = re.sub(r'\.(sin|cos|tan)\(mes=', r'.\1(', s)   # mes=RAD and plain RAD are the same IR
    s = re.sub(r'\b(\d+)\.0im', r'\1im', s)            # 1.0im and 1im are the same IR
    s = re.sub(r'(?<![\w.])sort\(([\w.]+)\);', r'\1.sort();', s)   # sort(a) and a.sort() are the same IR
    s = re.sub(r'^(?:private|public)function', 'function', s)    # visibility is not in the IR
    s = s.replace(')->null{', '){')           # the source sometimes omits -> null
    s = re.sub(r'\.rows\b', '.length', s)     # 2D arrays: .rows and .length are the same IR
    s = re.sub(r'alloc\w+\[0\]\[0\]', '[[]]', s)             # alloc T[0][0] and [[]] are the same IR
    s = re.sub(r'\bfloat\(([\w.\[\]]+)\)', r'\1', s)         # float(i) and the implicit int->float promotion are the same IR
    s = re.sub(r'\bfloat\(([^()]*)\)', r'(\1)', s)
    while True:                                # float(f(...)): an explicit cast around a call is invisible in the IR
        fm_ = re.search(r'\bfloat\(', s)
        if not fm_:
            break
        depth, j = 1, fm_.end()
        while j < len(s) and depth:
            depth += (s[j] == '(') - (s[j] == ')')
            j += 1
        if depth:
            break
        s = s[:fm_.start()] + s[fm_.end():j - 1] + s[j:]
    s = re.sub(r'(?<![\w)\]*/%+\-])\(([\w.\[\]]+(?:[*/%][\w.\[\]]+)*)\)(?=[*/%])', r'\1', s)   # (a % b) / c and a % b / c: same left-to-right IR
    s = s.replace(',}', '}')                  # trailing comma in a multi-line { } literal
    m_ = re.fullmatch(r'return\((.*)\);', s)             # return (x); and return x; are the same IR
    if m_:
        depth, ok = 0, True
        for ch in m_.group(1):
            depth += (ch == '(') - (ch == ')')
            if depth < 0:                                # the first ( closes early: return (a) + (b); keeps its parentheses
                ok = False
                break
        if ok and depth == 0:
            s = f'return{m_.group(1)};'
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

def cx_loose(s):
    # a.add(b) and a + b are the same IR: compare with the method form turned into the operator and all parentheses dropped
    s = re.sub(r'\.(add|sub|mul|div)\(', lambda m: {'add': '+', 'sub': '-', 'mul': '*', 'div': '/'}[m.group(1)] + '(', s)
    return s.replace('(', '').replace(')', '')

def line_matches(src, n, stmt):
    a, b = src_norm(src, n), norm(stmt)
    om_ = re.match(r'^(?:private|public)?function\w+\(.*?\)(?:->[^{]+)?\{(.*)\};?$', a)
    if om_ and norm(stmt).rstrip(";") != "" and not b.endswith("{"):      # a whole function written on one line: the statement only has to be inside its body
        body_ = re.sub(r'([\w.\[\]]+)([-+*/%])=(?!=)([\w.]+);', r'\1=\1\2\3;', om_.group(1))     # a += b inside a one-line body is a = a + b, same IR
        if b in body_ or b.rstrip(";") in body_ or b.replace(";", "") in body_.replace(";", ""):
            return True
    hm_ = re.match(r'^(default:|case[^:]+:)(.+)$', b)
    if hm_ and a == hm_.group(2):           # we glued "default: stmt;" but the source has the header on the line above
        return True
    if a == b or merge_prints(a) == merge_prints(b):
        return True
    if "}" in a and loose(a) == loose(b):      # one-line if/else in the source
        return True
    return cx_loose(a) == cx_loose(b)


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
    th_ = re.sub(r'\};?$', '', norm(text))
    if th_ != norm(head) and th_.startswith(norm(head)):       # a one-line function: the header is the part up to the first {
        return True, n, text # type: ignore
    return th_ == norm(head), n, text # type: ignore


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