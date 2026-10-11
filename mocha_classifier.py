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
    """label -> set of labels that dominate it (every path from entry passes through them)."""
    nodes = list(cfg)
    preds = {n: [] for n in nodes}
    for n, succs in cfg.items():
        for s in succs:
            preds[s].append(n)
    dom = {n: set(nodes) for n in nodes}
    dom[entry] = {entry}
    changed = True
    while changed:
        changed = False
        for n in nodes:
            if n == entry:
                continue
            ps = [dom[p] for p in preds[n]]
            new = {n} | (set.intersection(*ps) if ps else set())
            if new != dom[n]:
                dom[n] = new
                changed = True
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