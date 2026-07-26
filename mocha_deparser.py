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
                func.blocks[current_label].instrs.append(parse_instr(l))
            i += 1

        functions[fname] = func
    return functions

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