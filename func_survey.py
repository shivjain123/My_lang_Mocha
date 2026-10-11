import glob
from collections import defaultdict
from mocha_deparser import parse_module

groups = defaultdict(lambda: [0, set(), []])   # key -> [count, files, example names]

for path in sorted(glob.glob("*.ll")):
    with open(path, "r", encoding="utf-8") as f:
        funcs = parse_module(f.read())
    for name in funcs:
        if name.startswith("mocha_entry_"):
            key = "mocha_entry_*"
        elif "__" in name:
            key = "*__" + name.rsplit("__", 1)[-1]
        elif "_" in name:
            key = "*_" + name.rsplit("_", 1)[-1]
        else:
            key = name
        g = groups[key]
        g[0] += 1
        g[1].add(path)
        if len(g[2]) < 3 and name not in g[2]:
            g[2].append(name)

for key, (n, fset, ex) in sorted(groups.items(), key=lambda kv: -kv[1][0]):
    print(f"{n:5}  {len(fset):4} files  {key:22} e.g. {', '.join(ex)}")