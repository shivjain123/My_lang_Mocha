from mocha_deparser import parse_module   # <- copy your real import line here

funcs = parse_module(open("tag_name_test.ll", encoding="utf-8").read())
fn = funcs["DSKind__name"]

for label in fn.block_order:
    print(f"[{label}]")
    for i in fn.blocks[label].instrs:
        print(f"   op={i.op!r:10} {i.raw[:100]}")