import glob
import re
from collections import Counter
from mocha_deparser import parse_module
from mocha_classifier import build_cfg, dominators


def prefix(label):
    return re.sub(r'[_.]?\d+$', '', label)


back = Counter()
step_preds = Counter()
example = {}

for path in sorted(glob.glob("*.ll")):
    with open(path, "r", encoding="utf-8") as f:
        funcs = parse_module(f.read())
    for fn in funcs.values():
        if fn.name == "main":
            continue
        cfg = build_cfg(fn)
        dom = dominators(cfg, fn.block_order[0])
        preds = {n: [] for n in cfg}
        for a, succs in cfg.items():
            for b in succs:
                preds[b].append(a)
                if b in dom[a]:                      # b dominates a -> back edge
                    key = (prefix(b), prefix(a))     # (header, latch)
                    back[key] += 1
                    example.setdefault(key, f"{path} / {fn.name} / {a} -> {b}")
        for label in fn.block_order:
            if prefix(label) in ("for_step", "foreach_step"):
                key = (prefix(label), tuple(sorted(prefix(p) for p in preds[label])))
                step_preds[key] += 1

print("Back edges (header <- latch):")
for (header, latch), n in sorted(back.items(), key=lambda kv: (kv[0][0], -kv[1])):
    print(f"  {n:5}  {header:18} <- {latch:14} e.g. {example[(header, latch)]}")

print("\nWho jumps INTO each step block:")
for (step, ps), n in step_preds.most_common():
    print(f"  {n:3}  {step} <- {', '.join(ps)}")