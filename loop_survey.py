import glob
import re
from collections import Counter, defaultdict
from mocha_deparser import parse_module

LOOP_RE = re.compile(r'^(while|for|foreach_set|foreach|dowhile|lc)_([a-z]+)_(\d+)$')

sigs = defaultdict(Counter)        # family -> Counter of role-tuples
example = {}

for path in sorted(glob.glob("*.ll")):
    with open(path, "r", encoding="utf-8") as f:
        funcs = parse_module(f.read())
    for fn in funcs.values():
        groups = defaultdict(list)
        for label in fn.block_order:
            m = LOOP_RE.match(label)
            if m:
                groups[(m.group(1), m.group(3))].append(m.group(2))
        for (family, lid), roles in groups.items():
            sig = tuple(roles)          # kept in IR order
            sigs[family][sig] += 1
            example.setdefault((family, sig), f"{path} / {fn.name} / id {lid}")

for family, counter in sigs.items():
    print(f"\n=== {family} ===")
    for sig, n in counter.most_common():
        print(f"  {n:5}  {' -> '.join(sig)}    e.g. {example[(family, sig)]}")