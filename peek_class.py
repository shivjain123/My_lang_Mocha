from mocha_deparser import parse_module

funcs = parse_module(open("caps_class_test.ll", encoding="utf-8").read())

print("Functions and params:")
for name, fn in funcs.items():
    print(f"  {name}({', '.join(t + ' ' + n for t, n in fn.params)}) -> {fn.ret_type}")

for target in ["T_constructor", "T_drop"]:
    fn = funcs[target]
    print(f"\n=== {target} ===")
    for label in fn.block_order:
        print(f"[{label}]")
        for i in fn.blocks[label].instrs[:15]:
            print("   ", i.raw[:110])