import glob
from mocha_deparser import parse_module
from mocha_classifier import classify_function

for path in sorted(glob.glob("*.ll")):
    with open(path, "r", encoding="utf-8") as f:
        funcs = parse_module(f.read())
    classes = set()
    for fn in funcs.values():
        kind, owner = classify_function(fn)
        if kind == "ctor":
            classes.add(owner)
    for fn in funcs.values():
        kind, _ = classify_function(fn)
        if kind != "plain":
            continue
        for c in classes:
            if fn.name.startswith(c + "_"):
                ptypes = ", ".join(t for t, _ in fn.params)
                print(f"{path}: {fn.name}({ptypes}) -> {fn.ret_type}")