from mocha_deparser import parse_module

funcs = parse_module(open("class_rc_test.ll", encoding="utf-8").read())

for target in ["Named_drop", "Named_constructor"]:
    fn = funcs[target]
    print(f"=== {target}({', '.join(t + ' ' + n for t, n in fn.params)}) ===")
    for label in fn.block_order:
        print(f"[{label}]")
        for i in fn.blocks[label].instrs:
            print("   ", i.raw[:120])
    print()