import re, glob, json, collections, os
HERE = os.path.dirname(os.path.abspath(__file__))

pat = re.compile(r'\bfunction\s+(\w+)\s*\(.*\)\s*->\s*([^;{]*?)\s*\bnative\s+(\w+)\s*;')
rets = {}                                 # native callee -> declared return types
names = collections.defaultdict(set)      # native callee -> source names ('.name' = a method of a class)
class_rx = re.compile(r'^\s*(?:\w+\s+)*class\s+\w+')
for p in sorted(glob.glob(os.path.join(HERE, "lib", "*.mch"))):
    depth, stack = 0, []                  # stack of [depth where a class started, its '{' seen yet?]
    for line in open(p, encoding="utf-8", errors="replace"):
        if line.lstrip().startswith(("//", "~~")):
            continue
        if class_rx.match(line):
            stack.append([depth, False])
        m = pat.search(line)
        if m and line.lstrip().startswith("local "):
            m = None                      # a local native can only be called from its own file: user code never carries its symbol
        if m:
            inside = bool(stack) and stack[-1][1]
            names[m.group(3)].add(("." if inside else "") + m.group(1))
            rets.setdefault(m.group(3), set()).add(re.sub(r'\s+', '', m.group(2)))
        depth += line.count("{") - line.count("}")
        if stack and not stack[-1][1] and depth > stack[-1][0]:
            stack[-1][1] = True
        elif stack and stack[-1][1] and depth <= stack[-1][0]:
            stack.pop()

table = {k: next(iter(v)) for k, v in names.items() if len(v) == 1}
conflicts = {k: v for k, v in names.items() if len(v) > 1}
print(f"{len(names)} native callees, {len(table)} unique, {len(conflicts)} conflicting")
for k, v in list(conflicts.items())[:10]:
    print(f"   conflict {k}: {sorted(v)}")
for k in [k for k in table if k.startswith("ink_")][:5]:
    print(f"   sample {k} -> {table[k]}")
with open(os.path.join(HERE, "native_aliases.json"), "w", encoding="utf-8") as fh:
    json.dump(table, fh, indent=1, sort_keys=True)
print("📄 written to ..\\native_aliases.json")
nret = {k: next(iter(v)) for k, v in rets.items() if len(v) == 1}
with open("..\\native_rets.json", "w", encoding="utf-8") as fh:
    json.dump(nret, fh, indent=1, sort_keys=True)
print(f"📄 {len(nret)} native return types written to ..\\native_rets.json")