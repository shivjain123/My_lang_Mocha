import glob
from mocha_deparser import parse_module
from mocha_classifier import build_cfg

best = {}   # shape -> (size, path, fn)

for path in sorted(glob.glob("*.ll")):
    with open(path, "r", encoding="utf-8") as f:
        funcs = parse_module(f.read())
    for fn in funcs.values():
        if fn.name == "main":
            continue
        cfg = build_cfg(fn)
        size = sum(len(b.instrs) for b in fn.blocks.values())
        for label, succ in cfg.items():
            if len(succ) == 2 and succ[0].startswith("if_then"):
                if succ[1].startswith("if_else"):
                    shape = "if/else"
                elif succ[1].startswith("if_end"):
                    shape = "if (no else)"
                else:
                    continue
                if shape not in best or size < best[shape][0]:
                    best[shape] = (size, path, fn)

for shape, (size, path, fn) in best.items():
    cfg = build_cfg(fn)
    print(f"\n######## {shape}: {path} / {fn.name} ({size} instrs) ########")
    for label in fn.block_order:
        print(f"[{label}]  -> {cfg[label]}")
        for i in fn.blocks[label].instrs:
            if "mocha_stack_" in i.raw:
                continue
            print("    ", i.raw[:100])