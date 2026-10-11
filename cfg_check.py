import glob
from mocha_deparser import parse_module
from mocha_classifier import build_cfg, TERMINATORS

problems = 0
funcs_checked = 0

for path in sorted(glob.glob("*.ll")):
    with open(path, "r", encoding="utf-8") as f:
        funcs = parse_module(f.read())
    for fn in funcs.values():
        funcs_checked += 1
        cfg = build_cfg(fn)

        for label in fn.block_order:
            instrs = fn.blocks[label].instrs
            if not instrs or instrs[-1].op not in TERMINATORS:
                last = instrs[-1].raw[:70] if instrs else "<empty block>"
                print(f"❌ {path} | {fn.name} | {label}: no terminator, ends with: {last}")
                problems += 1
            for target in cfg[label]:
                if target not in fn.blocks:
                    print(f"❌ {path} | {fn.name} | {label}: jumps to missing block '{target}'")
                    problems += 1

        # reachability from the first block
        seen, stack = set(), [fn.block_order[0]]
        while stack:
            cur = stack.pop()
            if cur in seen or cur not in cfg:
                continue
            seen.add(cur)
            stack.extend(cfg[cur])
        for label in fn.block_order:
            if label not in seen:
                print(f"⚠️  {path} | {fn.name} | {label}: unreachable from entry")

print(f"\nChecked {funcs_checked} functions, {problems} real problems")