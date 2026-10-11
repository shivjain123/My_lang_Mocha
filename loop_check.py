import glob
from collections import Counter
from mocha_deparser import parse_module
from mocha_classifier import find_loops, build_cfg, dominators

EXPECTED = {"while": 208, "for": 5, "foreach": 14, "foreach_set": 9, "lc": 13, "dowhile": 1}
counts, problems = Counter(), 0

for path in sorted(glob.glob("*.ll")):
    with open(path, "r", encoding="utf-8") as f:
        funcs = parse_module(f.read())
    for fn in funcs.values():
        if fn.name == "main":
            continue
        loops = find_loops(fn)
        dom = dominators(build_cfg(fn), fn.block_order[0])
        for lp in loops:
            counts[lp["family"]] += 1
            where = f"{path} | {fn.name} | {lp['header']}"
            if lp["end"] not in fn.blocks:
                print(f"❌ {where}: exit block {lp['end']} doesn't exist")
                problems += 1
            elif lp["end"] in lp["body"]:
                print(f"❌ {where}: exit block is inside its own body")
                problems += 1
            for b in lp["body"]:
                if lp["header"] not in dom[b]:
                    print(f"❌ {where}: {b} in body but header doesn't dominate it")
                    problems += 1
        for i, a in enumerate(loops):              # loops must nest or be disjoint
            for b in loops[i + 1:]:
                inter = a["body"] & b["body"]
                if inter and inter != a["body"] and inter != b["body"]:
                    print(f"❌ {path} | {fn.name}: {a['header']} and {b['header']} partially overlap")
                    problems += 1

print("\nfamily        found  expected")
for fam, exp in EXPECTED.items():
    flag = "✅" if counts[fam] == exp else "❌"
    print(f"{fam:12} {counts[fam]:6} {exp:8}  {flag}")
print(f"\n{problems} problems")