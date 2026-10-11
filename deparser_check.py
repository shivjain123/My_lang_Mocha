import glob
import re
from mocha_deparser import parse_module, FUNC_DEF_RE   # <- your parser file's name

DEFINE_RE = re.compile(r'^define\b', re.M)

for path in sorted(glob.glob("*.ll")):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    expected = len(DEFINE_RE.findall(text))
    funcs = parse_module(text)
    blocks = sum(len(fn.blocks) for fn in funcs.values())
    instrs = sum(len(b.instrs) for fn in funcs.values() for b in fn.blocks.values())
    blank = sum(1 for fn in funcs.values() for b in fn.blocks.values()
                for i in b.instrs if not i.op)

    ok = (expected == len(funcs))
    print(f"{'✅' if ok else '❌'} {path}: {len(funcs)}/{expected} functions, "
          f"{blocks} blocks, {instrs} instrs, {blank} with empty op")

    if not ok:
        for line in text.splitlines():
            if line.startswith("define") and not FUNC_DEF_RE.match(line.strip()):
                print("     missed:", line[:110])