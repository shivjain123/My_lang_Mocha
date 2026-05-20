// ── Wren FFI ──
function wren_new() -> null native mocha_wren_new;
function wren_free(vm: null) -> null native mocha_wren_free;
function wren_dostring(vm: null, module: str, code: str) -> int native mocha_wren_dostring;
function wren_dofile(vm: null, filename: str) -> int native mocha_wren_dofile;
function wren_safe_dostring(vm: null, module: str, code: str) -> str native mocha_wren_safe_dostring;
function wren_eval_number(vm: null, expr: str) -> float native mocha_wren_eval_number;
function wren_eval_string(vm: null, expr: str) -> str native mocha_wren_eval_string;
function wren_eval_int(vm: null, expr: str) -> int native mocha_wren_eval_int;
function wren_eval_bool(vm: null, expr: str) -> int native mocha_wren_eval_bool;
function wren_call_number(vm: null, module: str, classname: str, sig: str) -> float native mocha_wren_call_number;
function wren_call_string(vm: null, module: str, classname: str, sig: str) -> str native mocha_wren_call_string;
function wren_call_int(vm: null, module: str, classname: str, sig: str) -> int native mocha_wren_call_int;
function wren_call1n_number(vm: null, module: str, classname: str, sig: str, arg: float) -> float native mocha_wren_call1n_number;
function wren_call1s_string(vm: null, module: str, classname: str, sig: str, arg: str) -> str native mocha_wren_call1s_string;
function wren_call2n_number(vm: null, module: str, classname: str, sig: str, a: float, b: float) -> float native mocha_wren_call2n_number;
function wren_call2s_string(vm: null, module: str, classname: str, sig: str, a: str, b: str) -> str native mocha_wren_call2s_string;

function wren_test(didLoad) -> null {
    var vm: null = wren_new();

    // Basic print
    wren_dostring(vm, "main", "System.print(\"Hello from Wren!\")");

    // Arithmetic via eval
    var result: float = wren_eval_number(vm, "2.0 + 3.0 * 4.0");
    print("2 + 3*4 = ", result, newLine=true);  // 14.0

    // String eval
    var s: str = wren_eval_string(vm, "\"Hello \" + \"Wren\"");
    print("string concat: ", s, newLine=true);

    // Define a class and call a method
    var wren_class: str = "class MathHelper {\n  static square(x) {\n    return x * x\n  }\n  static greet(name) {\n    return \"Hello, \" + name + \"!\"\n  }\n}";

    wren_dostring(vm, "mathmodule", wren_class);
    print("calling square...", newLine=true);
var sq: float = wren_call1n_number(vm, "mathmodule", "MathHelper", "square(_)", 5.0);
print("square(5) = ", sq, newLine=true);
print("calling greet...", newLine=true);
var greeting: str = wren_call1s_string(vm, "mathmodule", "MathHelper", "greet(_)", "Mocha");
print("greet: ", greeting, newLine=true);
    // File execution
    // wren_dofile(vm, "test.wren");

    wren_free(vm);
    print("Wren test done!", newLine=true);
};