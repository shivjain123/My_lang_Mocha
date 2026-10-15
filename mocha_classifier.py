import re
from mocha_deparser import Function

STRUCT_RE = re.compile(r'^%struct\.([\w.]+)\*$')


def _owner(fn: Function):
    """Class name if the first param is a %struct.X*, else None."""
    if not fn.params:
        return None
    m = STRUCT_RE.match(fn.params[0][0].strip())
    return m.group(1) if m else None


def _is_trivial(fn: Function) -> bool:
    """True if the body is just 'ret void' (an empty default)."""
    instrs = [i for b in fn.blocks.values() for i in b.instrs]
    return len(instrs) == 1 and instrs[0].op == "ret"

RELEASE_CALL_RE = re.compile(r'call\b.*@(\w+)')

def _is_generated_cleanup(fn: Function) -> bool:
    """True if the body only does gep/load/ret plus calls to *release* functions."""
    for b in fn.blocks.values():
        for i in b.instrs:
            if i.op in ("getelementptr", "load", "ret"):
                continue
            if i.op == "call":
                m = RELEASE_CALL_RE.search(i.text)
                if m and "release" in m.group(1):
                    continue
            return False
    return True


def find_classes(funcs: dict) -> set:
    """Class names in a module = owners of constructors."""
    classes = set()
    for fn in funcs.values():
        owner = _owner(fn)
        if owner and fn.name == f"{owner}_constructor":
            classes.add(owner)
    return classes


def classify_function(fn: Function, classes: set = frozenset()): # type: ignore
    """Returns (kind, owner_class_or_None).

    kinds: c_main, entry, lambda, ext_method, enum_name, ctor, release,
           drop_empty, drop_user, method, static_method, plain
    """
    name = fn.name
    if name == "main":
        return "c_main", None
    if name.startswith("mocha_entry_"):
        return "entry", None
    if name.startswith("mocha_lambda_"):
        return "lambda", None
    if name.startswith("mocha_ext_"):
        return "ext_method", None
    if name.endswith("__name"):
        return "enum_name", None

    owner = _owner(fn)
    if owner:
        if name == f"{owner}_constructor":
            return "ctor", owner
        if name == f"{owner}_release":
            return "release", owner
        if name == f"{owner}_drop":
            if _is_trivial(fn):
                return "drop_empty", owner
            if _is_generated_cleanup(fn):
                return "drop_generated", owner
            return "drop_user", owner
        if name.startswith(f"{owner}_"):
            return "method", owner

    # no 'this' param: static method if the name starts with a known class
    # (longest class name wins, in case of overlapping prefixes)
    for c in sorted(classes, key=len, reverse=True):
        if name.startswith(c + "_"):
            return "static_method", c
    return "plain", None


def classify_module(funcs: dict) -> dict:
    """name -> (kind, owner) for every function in a parsed module."""
    classes = find_classes(funcs)
    return {name: classify_function(fn, classes) for name, fn in funcs.items()}

TERMINATORS = ("br", "switch", "ret", "unreachable")
LABEL_REF_RE = re.compile(r'label\s+%([\w.]+)')


def successors(fn: Function, label: str) -> list:
    """Labels control can jump to from the end of this block, in IR order.
    br i1 -> [then, else];  switch -> [default, case0, case1, ...];
    ret / unreachable -> []"""
    instrs = fn.blocks[label].instrs
    if not instrs:
        return []
    last = instrs[-1]
    if last.op in ("br", "switch"):
        return LABEL_REF_RE.findall(last.text)
    return []


def build_cfg(fn: Function) -> dict:
    """label -> list of successor labels, for every block."""
    return {label: successors(fn, label) for label in fn.block_order}

IF_THEN_RE = re.compile(r'^if_then_(\d+)$')


def dominators(cfg: dict, entry: str) -> dict:
    """label -> set of labels that dominate it. Blocks unreachable from entry
    are ignored when computing the others and get just {themselves}."""
    reach, stack = set(), [entry]
    while stack:
        n = stack.pop()
        if n in reach:
            continue
        reach.add(n)
        stack.extend(cfg[n])
    nodes = [n for n in cfg if n in reach]
    preds = {n: [] for n in nodes}
    for n in nodes:
        for s in cfg[n]:
            preds[s].append(n)
    dom = {n: set(nodes) for n in nodes}
    dom[entry] = {entry}
    changed = True
    while changed:
        changed = False
        for n in nodes:
            if n == entry:
                continue
            new = {n} | set.intersection(*[dom[p] for p in preds[n]])
            if new != dom[n]:
                dom[n] = new
                changed = True
    for n in cfg:
        if n not in reach:
            dom[n] = {n}
    return dom


def region(cfg: dict, dom: dict, start: str, stop: str):
    """Blocks dominated by `start`, reached without entering `stop`.
    Returns (inside, exits): exits are blocks outside that the region jumps to
    (this is where break/continue show up)."""
    inside, exits, stack = set(), set(), [start]
    while stack:
        cur = stack.pop()
        if cur in inside or cur == stop:
            continue
        if start not in dom[cur]:
            exits.add(cur)
            continue
        inside.add(cur)
        stack.extend(cfg[cur])
    return inside, exits


def find_ifs(fn: Function) -> list:
    """Every if / if-else in a function, found via the if_then_N / if_else_N / if_end_N labels."""
    cfg = build_cfg(fn)
    dom = dominators(cfg, fn.block_order[0])
    found = []
    for label in fn.block_order:
        succ = cfg[label]
        if len(succ) != 2:
            continue
        m = IF_THEN_RE.match(succ[0])
        if not m:
            continue
        n = m.group(1)
        end = f"if_end_{n}"
        has_else = (succ[1] == f"if_else_{n}")
        then_in, then_exits = region(cfg, dom, succ[0], end)
        if has_else:
            else_in, else_exits = region(cfg, dom, succ[1], end)
        else:
            else_in, else_exits = set(), set()
        found.append({
            "id": n, "cond_block": label, "has_else": has_else,
            "second_target": succ[1], "end": end,
            "then": then_in, "then_exits": then_exits,
            "else": else_in, "else_exits": else_exits,
            "then_falls_through": any(end in cfg[b] for b in then_in),
            "else_falls_through": any(end in cfg[b] for b in else_in),
        })
    return found

LOOP_HEADERS = {
    "while_cond": "while",
    "for_cond": "for",
    "foreach_cond": "foreach",
    "foreach_set_cond": "foreach_set",
    "lc_loop": "lc",
    "dowhile_body": "dowhile",
}
LABEL_ID_RE = re.compile(r'^(.*)_(\d+)$')


def find_loops(fn: Function) -> list:
    """Every loop in a function, found via back edges to known loop headers.
    The body is the natural loop: header + everything that reaches a latch
    without passing back through the header."""
    cfg = build_cfg(fn)
    dom = dominators(cfg, fn.block_order[0])
    preds = {n: [] for n in cfg}
    for a, succs in cfg.items():
        for b in succs:
            preds[b].append(a)

    latches = {}                                  # header -> [latch, ...]
    for a, succs in cfg.items():
        for b in succs:
            if b in dom[a]:                       # b dominates a -> back edge
                m = LABEL_ID_RE.match(b)
                if m and m.group(1) in LOOP_HEADERS:
                    latches.setdefault(b, []).append(a)

    loops = []
    for header, ls in latches.items():
        prefix, lid = LABEL_ID_RE.match(header).groups() # type: ignore
        family = LOOP_HEADERS[prefix]
        body, stack = {header}, list(ls)
        while stack:
            n = stack.pop()
            if n in body:
                continue
            body.add(n)
            stack.extend(preds[n])
        loops.append({
            "family": family, "id": lid, "header": header,
            "latches": ls, "body": body, "end": f"{family}_end_{lid}",
        })
    return loops

LC_ROLE_RE = re.compile(r'^lc_([a-z]+)_(\d+)$')


def describe_lc(fn: Function, lp: dict) -> dict:
    """Kind and loop variable of a list-comprehension loop.
    kinds: plain, filtered (append + skip), ternary (then + else; still a guess)"""
    roles = {}
    for b in lp["body"]:
        m = LC_ROLE_RE.match(b)
        if m and m.group(2) == lp["id"]:
            roles[m.group(1)] = b
    if "append" in roles and "skip" in roles:
        kind = "filtered"
    elif "then" in roles and "else" in roles:
        kind = "ternary"
    else:
        kind = "plain"

    var = None
    var_re = re.compile(r'%lc_(\w+?)_' + lp["id"] + r'\.ptr')
    for b in lp["body"]:
        for i in fn.blocks[b].instrs:
            m = var_re.search(i.raw)
            if m:
                var = m.group(1)
                break
        if var:
            break
    return {"kind": kind, "var": var, "roles": roles}

def find_shortcircuits(fn: Function) -> list:
    """Every and/or expression in a function, found via the branch that
    jumps to both X_right_N and X_done_M."""
    cfg = build_cfg(fn)
    dom = dominators(cfg, fn.block_order[0])
    found = []
    for left, succ in cfg.items():
        if len(succ) != 2:
            continue
        for kind in ("and", "or"):
            right = next((s for s in succ if s.startswith(f"{kind}_right_")), None)
            done = next((s for s in succ if s.startswith(f"{kind}_done_")), None)
            if not (right and done):
                continue
            inside, exits = region(cfg, dom, right, done)
            found.append({
                "kind": kind, "left": left, "right": right, "done": done,
                "right_region": inside, "right_exits": exits,
                "branch_order": "right_first" if succ[0] == right else "done_first",
            })
    return found

MATCH_LABEL_RE = re.compile(r'^match_(case|body|default|end)_(\d+)(?:_(\d+))?$')
ICMP_EQ_RE = re.compile(r'icmp eq i32 (%[\w.]+), (%[\w.]+)')
LOAD_GLOBAL_RE = re.compile(r'(%[\w.]+) = load i32, i32\* @([\w.]+)')


def find_matches(fn: Function) -> list:
    """Every plain match in a function (value cases only, no ranges yet)."""
    cfg = build_cfg(fn)
    dom = dominators(cfg, fn.block_order[0])
    groups = {}
    for b in fn.block_order:
        m = MATCH_LABEL_RE.match(b)
        if not m:
            continue
        role, mid, idx = m.group(1), m.group(2), m.group(3)
        g = groups.setdefault(mid, {"case": {}, "body": {}, "default": None, "end": None})
        if role in ("case", "body"):
            g[role][int(idx)] = b
        else:
            g[role] = b

    found = []
    for mid, g in groups.items():
        end = g["end"]
        cases = []
        for n in sorted(g["case"]):
            cb = g["case"][n]
            loads, scrutinee, const = {}, None, None
            for i in fn.blocks[cb].instrs:
                m = LOAD_GLOBAL_RE.search(i.raw)
                if m:
                    loads[m.group(1)] = m.group(2)
                m = ICMP_EQ_RE.search(i.raw)
                if m:
                    scrutinee = m.group(1)
                    const = loads.get(m.group(2))
            body = g["body"].get(n)
            inside, exits = region(cfg, dom, body, end) if body and end else (set(), set())
            cases.append({
                "index": n, "test_block": cb, "body_block": body,
                "scrutinee": scrutinee, "const": const,
                "body_region": inside, "body_exits": exits,
                "falls_through": any(end in cfg[b] for b in inside) if end else False,
            })
        d = g["default"]
        d_in, d_exits = region(cfg, dom, d, end) if d and end else (set(), set())
        found.append({
            "id": mid, "cases": cases, "default": d, "end": end,
            "default_region": d_in, "default_exits": d_exits,
            "default_falls_through": any(end in cfg[b] for b in d_in) if end else False,
        })
    return found

POP_RE = re.compile(r'(%[\w.]+) = call i8\* @mocha_ex_pop\(\)')
BIND_RE = re.compile(r'store i8\* (%[\w.]+), i8\*\* %([\w.]+)\.ptr')
AFTER_RE = re.compile(r'label %(after_try_\d+)')
TRY_ID_RE = re.compile(r'^try_body_(\d+)$')


def _dead_is_plumbing(dead) -> bool:
    """A dead tail is compiler plumbing if it is only mocha_ex_pop calls and a br."""
    for i in dead:
        if i.op == "br":
            continue
        if i.op == "call" and "@mocha_ex_pop" in i.raw:
            continue
        return False
    return True


def user_dead_blocks(fn: Function) -> list:
    """Blocks whose dead tail holds real code (e.g. statements written after a fail)."""
    return [b for b in fn.block_order
            if fn.blocks[b].dead and not _dead_is_plumbing(fn.blocks[b].dead)]


def find_fails(fn: Function) -> list:
    """Blocks ending in `fail msg;` = mocha_ex_throw(...) followed by unreachable."""
    out = []
    for label in fn.block_order:
        ins = fn.blocks[label].instrs
        if len(ins) >= 2 and ins[-1].op == "unreachable" and "@mocha_ex_throw" in ins[-2].raw:
            out.append(label)
    return out


def find_trys(fn: Function) -> list:
    """Every try/rescue in a function, paired through the branch at the try site."""
    cfg = build_cfg(fn)
    dom = dominators(cfg, fn.block_order[0])
    found = []
    for site in fn.block_order:
        succ = cfg[site]
        if len(succ) != 2:
            continue
        resc = [s for s in succ if s.startswith("rescue_body_")]
        body = [s for s in succ if s.startswith("try_body_")]
        if not (resc and body):
            continue
        try_b, resc_b = body[0], resc[0]
        tid = int(TRY_ID_RE.match(try_b).group(1)) # type: ignore
        after = f"after_try_{tid + 2}"
        if after not in fn.blocks:
            after = None
        after_jump = None                      # cross-check: where do the two bodies jump?
        for b in (try_b, resc_b):
            for i in fn.blocks[b].instrs + fn.blocks[b].dead:
                m = AFTER_RE.search(i.raw)
                if m:
                    after_jump = m.group(1)
        stop = after or ""
        try_in, try_exits = region(cfg, dom, try_b, stop)
        resc_in, resc_exits = region(cfg, dom, resc_b, stop)

        binding, popped = None, None
        ins = fn.blocks[resc_b].instrs
        if ins:
            m = POP_RE.search(ins[0].raw)
            popped = m.group(1) if m else None
            if popped and len(ins) > 1:
                m2 = BIND_RE.search(ins[1].raw)
                if m2 and m2.group(1) == popped:
                    binding = re.sub(r'\.\d+$', '', m2.group(2))   # e.3 -> e

        found.append({
            "site": site, "id": tid, "try_block": try_b, "rescue_block": resc_b,
            "after": after, "after_jump": after_jump,
            "try_region": try_in, "try_exits": try_exits,
            "rescue_region": resc_in, "rescue_exits": resc_exits,
            "binding": binding, "rescue_pops": popped is not None,
            "branch_order_ok": succ == [resc_b, try_b],
            "ids_ok": resc_b == f"rescue_body_{tid + 1}",
        })
    for t in found:
        t["depth"] = sum(1 for o in found if o is not t
                         and (t["site"] in o["try_region"] or t["site"] in o["rescue_region"]))
    return found

if __name__ == "__main__":
    import glob
    from collections import Counter, defaultdict
    from mocha_deparser import parse_module

    kinds = Counter()
    samples = defaultdict(list)
    for path in sorted(glob.glob("*.ll")):
        with open(path, "r", encoding="utf-8") as f:
            funcs = parse_module(f.read())
        for name, (kind, owner) in classify_module(funcs).items():
            kinds[kind] += 1
            if kind in ("plain", "static_method"):
                samples[kind].append(f"{path}: {name}")

    for kind, n in kinds.most_common():
        print(f"{n:6}  {kind}")
    print("\n--- static_method ---")
    for s in samples["static_method"]:
        print("  ", s)