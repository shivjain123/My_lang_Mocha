import glob
import re
from collections import Counter, defaultdict
from mocha_deparser import parse_module

counts = Counter()
files = defaultdict(set)

for path in sorted(glob.glob("*.ll")):
    with open(path, "r", encoding="utf-8") as f:
        funcs = parse_module(f.read())
    for fn in funcs.values():
        for label in fn.block_order:
            prefix = re.sub(r'[_.]?\d+$', '', label)
            counts[prefix] += 1
            files[prefix].add(path)

for prefix, n in counts.most_common():
    print(f"{n:6}  {len(files[prefix]):4} files  {prefix}")