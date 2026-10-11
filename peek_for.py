import glob
from mocha_deparser import parse_module
from mocha_classifier import find_loops

shown = 0
for path in sorted(glob.glob("*.ll")):
    with open(path, "r", encoding="utf-8") as f:
        funcs = parse_module(f.read())
    for fn in funcs.values():
        if fn.name == "main":
            continue
        for lp in find_loops(fn):
            if lp["family"] != "for":
                continue
            shown += 1
            has_step = f"for_step_{lp['id']}" in fn.blocks
            print(f"\n######## {path} / {fn.name} / for id {lp['id']}  "
                  f"({'WITH' if has_step else 'NO'} step block) ########")
            for label in fn.block_order:
                if label not in lp["body"] and label != lp["end"]:
                    continue
                print(f"[{label}]")
                lines = [i.raw for i in fn.blocks[label].instrs if "mocha_stack_" not in i.raw]
                if len(lines) > 10:
                    lines = lines[:3] + ["   ..."] + lines[-6:]
                for l in lines:
                    print("    ", l[:100])

print(f"\n{shown} for loops shown")