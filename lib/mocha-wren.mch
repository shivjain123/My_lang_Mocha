~~ Mocha-Wren FFI Library
~~ Provides bidirectional Wren integration for Mocha programs.
~~ Use wren_open() to create a Wren VM and wren_close() to destroy it.
~~ Wren is class-based — most call functions require a module and class name.

~~ Creates a new Wren VM. Returns an opaque handle.
function wren_open() -> null native mocha_wren_new;

~~ Closes and destroys a Wren VM.
~~ @param vm  the Wren VM handle
function wren_close(vm: null) -> null native mocha_wren_free;

~~ Runs Wren source code in a named module. Returns 0 on success.
~~ @param vm      the Wren VM handle
~~ @param module  name for this code module
~~ @param code    Wren source code to execute
function wren_run(vm: null, module: str, code: str) -> int native mocha_wren_dostring;

~~ Runs a Wren file. Returns 0 on success.
~~ @param vm        the Wren VM handle
~~ @param filename  path to the .wren file
function wren_run_file(vm: null, filename: str) -> int native mocha_wren_dofile;

~~ Runs Wren source code safely. Returns error message or empty string.
~~ @param vm      the Wren VM handle
~~ @param module  name for this code module
~~ @param code    Wren source code to execute
function wren_try(vm: null, module: str, code: str) -> str native mocha_wren_safe_dostring;

~~ Evaluates a Wren expression and returns a float.
~~ @param vm    the Wren VM handle
~~ @param expr  Wren expression to evaluate
function wren_eval_number(vm: null, expr: str) -> float native mocha_wren_eval_number;

~~ Evaluates a Wren expression and returns a string.
~~ @param vm    the Wren VM handle
~~ @param expr  Wren expression to evaluate
function wren_eval_string(vm: null, expr: str) -> str native mocha_wren_eval_string;

~~ Evaluates a Wren expression and returns an int.
~~ @param vm    the Wren VM handle
~~ @param expr  Wren expression to evaluate
function wren_eval_int(vm: null, expr: str) -> int native mocha_wren_eval_int;

~~ Evaluates a Wren boolean expression. Returns true or false.
~~ @param vm    the Wren VM handle
~~ @param expr  Wren boolean expression to evaluate
function wren_eval_bool(vm: null, expr: str) -> bool native mocha_wren_eval_bool;

~~ Calls a no-arg Wren static method, returns float.
~~ @param vm         the Wren VM handle
~~ @param module     module where the class is defined
~~ @param classname  Wren class name
~~ @param sig        method signature e.g. "myMethod"
function wren_call_number(vm: null, module: str, classname: str, sig: str) -> float native mocha_wren_call_number;

~~ Calls a no-arg Wren static method, returns str.
~~ @param vm         the Wren VM handle
~~ @param module     module where the class is defined
~~ @param classname  Wren class name
~~ @param sig        method signature e.g. "myMethod"
function wren_call_string(vm: null, module: str, classname: str, sig: str) -> str native mocha_wren_call_string;

~~ Calls a no-arg Wren static method, returns int.
~~ @param vm         the Wren VM handle
~~ @param module     module where the class is defined
~~ @param classname  Wren class name
~~ @param sig        method signature e.g. "myMethod"
function wren_call_int(vm: null, module: str, classname: str, sig: str) -> int native mocha_wren_call_int;

~~ Calls a Wren static method with 1 float arg, returns float.
~~ @param vm         the Wren VM handle
~~ @param module     module where the class is defined
~~ @param classname  Wren class name
~~ @param sig        method signature e.g. "myMethod(_)"
~~ @param arg        numeric argument
function wren_call_number_1n(vm: null, module: str, classname: str, sig: str, arg: float) -> float native mocha_wren_call1n_number;

~~ Calls a Wren static method with 1 str arg, returns str.
~~ @param vm         the Wren VM handle
~~ @param module     module where the class is defined
~~ @param classname  Wren class name
~~ @param sig        method signature e.g. "myMethod(_)"
~~ @param arg        string argument
function wren_call_string_1s(vm: null, module: str, classname: str, sig: str, arg: str) -> str native mocha_wren_call1s_string;

~~ Calls a Wren static method with 2 float args, returns float.
~~ @param vm         the Wren VM handle
~~ @param module     module where the class is defined
~~ @param classname  Wren class name
~~ @param sig        method signature e.g. "myMethod(_,_)"
~~ @param a          first numeric argument
~~ @param b          second numeric argument
function wren_call_number_2n(vm: null, module: str, classname: str, sig: str, a: float, b: float) -> float native mocha_wren_call2n_number;

~~ Calls a Wren static method with 2 str args, returns str.
~~ @param vm         the Wren VM handle
~~ @param module     module where the class is defined
~~ @param classname  Wren class name
~~ @param sig        method signature e.g. "myMethod(_,_)"
~~ @param a          first string argument
~~ @param b          second string argument
function wren_call_string_2s(vm: null, module: str, classname: str, sig: str, a: str, b: str) -> str native mocha_wren_call2s_string;