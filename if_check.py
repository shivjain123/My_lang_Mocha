import glob
import re
from collections import Counter
from mocha_deparser import parse_module
from mocha_classifier import find_ifs

def prefix(label):
    return re.sub(r'[_.]?\d+$', '', label)

total = with_else = problems = 0
exit_kinds = Counter()
diverging = Counter()

for path in sorted(glob.glob("*.ll")):
    with open(path, "r", encoding="utf-8") as f:
        funcs = parse_module(f.read())
    for fn in funcs.values():
        for info in find_ifs(fn):
            total += 1
            where = f"{path} | {fn.name} | if_{info['id']}"
            n = info["id"]
            if info["has_else"]:
                with_else += 1
            elif info["second_target"] != info["end"]:
                print(f"❌ {where}: false edge goes to '{info['second_target']}', expected if_else/if_end")
                problems += 1
            if info["end"] not in fn.blocks:
                print(f"❌ {where}: {info['end']} doesn't exist")
                problems += 1
            if info["then"] & info["else"]:
                print(f"❌ {where}: then and else regions overlap")
                problems += 1
            for side in ("then", "else"):
                for e in info[f"{side}_exits"]:
                    exit_kinds[(side, prefix(e))] += 1
                if info[side] and not info[f"{side}_falls_through"]:
                    diverging[side] += 1

print(f"\n{total} ifs ({with_else} with else, {total - with_else} without), {problems} problems")
print("\nExit targets (side, label prefix) -> count:")
for (side, p), c in exit_kinds.most_common():
    print(f"  {c:5}  {side:5} {p}")
print(f"\nBranches that never reach if_end: {dict(diverging)}")