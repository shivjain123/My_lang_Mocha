import re
from dataclasses import dataclass, field

@dataclass
class Instr:
    raw: str          # full original line, trimmed
    result: str | None   # e.g. "%t7" if this instr assigns something, else None
    op: str            # e.g. "call", "load", "store", "br", "icmp", "add", "fadd", "getelementptr", "alloca", "ret"
    text: str          # everything after "result = " (or the whole line if no result)

@dataclass
class BasicBlock:
    label: str
    instrs: list[Instr] = field(default_factory=list)
    dead: list[Instr] = field(default_factory=list)   # unreachable tail after a terminator

@dataclass
class Function:
    name: str
    params: list[tuple[str, str]]   # (llvm_type, name)
    ret_type: str
    blocks: dict[str, BasicBlock] = field(default_factory=dict)
    block_order: list[str] = field(default_factory=list)

RESULT_RE = re.compile(r'^\s*(%[\w.]+)\s*=\s*(.*)$')
OP_RE     = re.compile(r'^\s*([a-zA-Z_][\w.]*)')

def parse_instr(line: str) -> Instr:
    line = line.strip()
    m = RESULT_RE.match(line)
    if m:
        result, rest = m.group(1), m.group(2)
    else:
        result, rest = None, line
    op_m = OP_RE.match(rest)
    op = op_m.group(1) if op_m else ""
    return Instr(raw=line, result=result, op=op, text=rest)

FUNC_DEF_RE = re.compile(
    r'^define\s+([\w.\*%\s]+?)\s+@([\w.]+)\s*\((.*?)\)\s*(?:\w+\s*)*\{$'
)
LABEL_RE = re.compile(r'^([\w.]+):$')
TERMINATOR_OPS = ("br", "switch", "ret", "unreachable")

def parse_module(ll_text: str) -> dict[str, Function]:
    functions = {}
    lines = ll_text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        m = FUNC_DEF_RE.match(line)
        if not m:
            i += 1
            continue
        ret_type, fname, param_str = m.groups()
        params = []
        for p in param_str.split(','):
            p = p.strip()
            if not p:
                continue
            parts = p.rsplit(' ', 1)
            if len(parts) == 2:
                params.append((parts[0].strip(), parts[1].strip()))
            else:
                params.append((p, ""))  # unnamed param

        func = Function(name=fname, params=params, ret_type=ret_type.strip())
        current_label = None
        i += 1

        while i < len(lines):
            l = lines[i].strip()
            if l == "}":
                i += 1
                break
            lbl_m = LABEL_RE.match(l)
            if lbl_m:
                current_label = lbl_m.group(1)
                func.blocks[current_label] = BasicBlock(label=current_label)
                func.block_order.append(current_label)
            elif l and not l.startswith(';'):
                if current_label is None:
                    # instructions before any label = implicit "entry"
                    current_label = "entry"
                    func.blocks[current_label] = BasicBlock(label=current_label)
                    func.block_order.append(current_label)
                # multi-line switch: "switch ... [" ... "]" becomes one Instr
                if l.endswith('['):
                    parts = [l]
                    i += 1
                    while i < len(lines) and lines[i].strip() != ']':
                        parts.append(lines[i].strip())
                        i += 1
                    parts.append(']')
                    l = ' '.join(parts)
                blk = func.blocks[current_label]
                if blk.instrs and blk.instrs[-1].op in TERMINATOR_OPS:
                    blk.dead.append(parse_instr(l))      # dead tail, kept out of the CFG
                else:
                    blk.instrs.append(parse_instr(l))
            i += 1

        functions[fname] = func
    return functions

PRELUDE_TYPES = {"MochaArray", "MochaArray2D", "MochaTuple", "MochaClosureBundle",
                 "MochaDict", "MochaSet", "struct.MochaStringBuilder", "struct.MochaComplex",
                 "struct.MochaFile", "struct.MochaHashTable", "MochaExFrame"}

STR_DEF_RE = re.compile(r'^@(\.str\d+) = private unnamed_addr constant \[(\d+) x i8\] c"(.*)"\s*$')
TYPE_DEF_RE = re.compile(r'^%([\w.]+) = type (.*)$')
TAG_DEF_RE = re.compile(r'^@(\w+?)__(\w+) = (external )?constant i32(?: (-?\d+))?\s*$')
HEX2 = re.compile(r'[0-9A-Fa-f]{2}')


@dataclass
class Globals:
    strings: dict = field(default_factory=dict)     # ".str0" -> decoded text
    tags: dict = field(default_factory=dict)        # enum -> {tag: value, or None if external}
    types: dict = field(default_factory=dict)       # "struct.T" -> [field llvm types]
    str_errors: list = field(default_factory=list)  # strings whose length/NUL didn't match


def decode_llvm_string(body: str) -> bytes:
    """Decode the inside of c"..." (\\XX hex escapes) into raw bytes."""
    out = bytearray()
    i = 0
    while i < len(body):
        if body[i] == '\\':
            m = HEX2.match(body, i + 1)
            if m:
                out.append(int(m.group(), 16))
                i += 3
                continue
        out.extend(body[i].encode("utf-8"))
        i += 1
    return bytes(out)


def split_top_level(s: str) -> list:
    """Split on commas that are not inside (), [], {} or <>."""
    parts, depth, cur = [], 0, ""
    for ch in s:
        if ch in "([{<":
            depth += 1
        elif ch in ")]}>":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur.strip())
    return parts


def parse_globals(ll_text: str) -> Globals:
    g = Globals()
    inside = False
    for raw in ll_text.splitlines():
        s = raw.rstrip()
        if s.startswith("define"):
            inside = True
            continue
        if inside:
            if s.strip() == "}":
                inside = False
            continue
        m = STR_DEF_RE.match(s)
        if m:
            name, n, body = m.group(1), int(m.group(2)), m.group(3)
            data = decode_llvm_string(body)
            if len(data) != n or not data.endswith(b"\x00"):
                g.str_errors.append(name)
            text = data[:-1] if data.endswith(b"\x00") else data
            g.strings[name] = text.decode("utf-8", errors="replace")
            continue
        m = TAG_DEF_RE.match(s)
        if m:
            enum, tag, external, value = m.groups()
            g.tags.setdefault(enum, {})[tag] = None if external else int(value)
            continue
        m = TYPE_DEF_RE.match(s)
        if m and m.group(1) not in PRELUDE_TYPES:
            body = m.group(2).strip()
            if body.startswith("{") and body.endswith("}"):
                g.types[m.group(1)] = split_top_level(body[1:-1])
            else:
                g.types[m.group(1)] = None          # opaque
    return g

if __name__ == "__main__":
    with open("geo_seisimo.ll", "r", encoding="utf-8") as f:
        ll_text = f.read()

    functions = parse_module(ll_text)

    print("Functions found:", list(functions.keys()))
    print()

    fn = functions["mocha_entry_main"]
    print("Blocks in mocha_entry_main:", fn.block_order)
    print()

    # peek at the first block's instructions
    first_block = fn.blocks[fn.block_order[0]]
    for instr in first_block.instrs[:10]:
        print(f"  op={instr.op!r:15} result={instr.result!r:10} text={instr.text}")
    
    print()
    print("=== and_right_231 ===")
    for instr in fn.blocks["and_right_231"].instrs:
        print(f"  op={instr.op!r:15} result={instr.result!r:10} text={instr.text}")

    print()
    print("=== and_done_232 ===")
    for instr in fn.blocks["and_done_232"].instrs:
        print(f"  op={instr.op!r:15} result={instr.result!r:10} text={instr.text}")