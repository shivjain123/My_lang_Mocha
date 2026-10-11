import glob
import re
from mocha_deparser import parse_module

WANT = ["do_exit", "do_continue", "chk", "dropit", "rel", "done"]
seen = set()

for path in sorted(glob.glob("*.ll"), key=lambda p: len(open(p, encoding="utf-8").read())):
    funcs = parse_module(open(path, encoding="utf-8").read())
    for fn in funcs.values():
        for label in fn.block_order:
            prefix = re.sub(r'[_.]?\d+$', '', label)
            if prefix in WANT and prefix not in seen:
                seen.add(prefix)
                print(f"=== {prefix}  ({path} / {fn.name} / {label}) ===")
                for i in fn.blocks[label].instrs[:8]:
                    print("   ", i.raw[:110])
                print()
    if seen == set(WANT):
        break