from "mocha-wren" import *;

function wren_test(didLoad) -> null {
    var vm: null = wren_open();

    // ── 1. Basic print ─────────────────────────────────────────────
    wren_run(vm, "main", "System.print(\"Hello from Wren!\")");

    // ── 2. Arithmetic via eval ─────────────────────────────────────
    var result: float = wren_eval_number(vm, "2.0 + 3.0 * 4.0");
    print("2 + 3*4 = " + str(result), newLine=true);

    // ── 3. String eval ─────────────────────────────────────────────
    var s: str = wren_eval_string(vm, "\"Hello \" + \"Wren\"");
    print("string concat: " + s, newLine=true);

    // ── 4. Class method calls ──────────────────────────────────────
    var math_class: str = "class MathHelper {\n  static square(x) {\n    return x * x\n  }\n  static greet(name) {\n    return \"Hello, \" + name + \"!\"\n  }\n}";

    wren_run(vm, "mathmodule", math_class);

    var sq: float = wren_call_number_1n(vm, "mathmodule", "MathHelper", "square(_)", 5.0);
    print("square(5) = " + str(sq), newLine=true);

    var greeting: str = wren_call_string_1s(vm, "mathmodule", "MathHelper", "greet(_)", "Mocha");
    print("greet: " + greeting, newLine=true);

    // ── 5. Safe execution ──────────────────────────────────────────
    var err: str = wren_try(vm, "main", "this is not valid wren !@#$");
    print("safe error: " + err, newLine=true);

    wren_close(vm);
    print("--- Wren FFI Done ---", newLine=true);
};