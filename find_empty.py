from mocha_deparser import parse_module   # <- copy your real import line here

for path in ["suite_of_v0.7.ll", "tag_name_test.ll", "tagging_chk.ll"]:
    with open(path, "r", encoding="utf-8") as f:
        funcs = parse_module(f.read())
    for fn in funcs.values():
        for label, block in fn.blocks.items():
            for i in block.instrs:
                if not i.op:
                    print(f"{path} | {fn.name} | {label}\n    {i.raw}\n")