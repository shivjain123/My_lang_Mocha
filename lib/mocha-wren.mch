"""
mocha-wren v0.2 — Wren FFI Library for Mocha

Section 1: VM Lifecycle (wren_open, wren_close)
Section 2: Running Code (wren_run, wren_run_file, wren_try)
Section 3: Evaluating Expressions (wren_eval_number, wren_eval_string,
           wren_eval_int, wren_eval_bool)
Section 4: Calling Static Methods (wren_call_number, wren_call_string,
           wren_call_int, wren_call_bool and the argument variants)

Notes: wren_open() returns an opaque VM handle, and every other function takes
it as the first argument. Close each VM with wren_close or it leaks; closing
twice is safe (the second call warns and is ignored). wren_run and
wren_run_file return 0 on success, 1 for a compile error and 2 for a runtime
error (wren_run_file also returns 3 if the file cannot be read), while
wren_try returns the error message, or an empty string on success. Wren code
can import "name" to load name.wren from the current folder. The eval
functions run in the module of the last wren_run, wren_run_file or wren_try
call (or "main" if there was none), so classes and variables defined there are
visible. Calls reach static methods only, because the receiver is the class
itself. The sig argument is the Wren method signature: "name" for a getter,
"name(_)" or "name(_,_)" for methods with arguments, and "name()" for a method
defined with empty parentheses. Only some argument and return combinations
exist (see the list of functions), not every one.

Part of the Mocha Scientific Library Ecosystem
License: Apache 2.0

"""

~~ Creates a new Wren VM. Returns an opaque handle.
function wren_open() -> null native mocha_wren_new;

~~ Closes and destroys a Wren VM. Closing the same VM twice is safe: the second call warns and is ignored.
~~ @param vm  the Wren VM handle
function wren_close(vm: null) -> null native mocha_wren_free;

~~ Runs Wren source code in a named module.
~~ Returns 0 on success, 1 on a compile error, 2 on a runtime error.
~~ @param vm      the Wren VM handle
~~ @param module  name for this code module
~~ @param code    Wren source code to execute
function wren_run(vm: null, module: str, code: str) -> int native mocha_wren_dostring;

~~ Runs a Wren file.
~~ Returns 0 on success, 1 on a compile error, 2 on a runtime error, 3 if the file could not be read.
~~ @param vm        the Wren VM handle
~~ @param filename  path to the .wren file
function wren_run_file(vm: null, filename: str) -> int native mocha_wren_dofile;

~~ Runs Wren source code safely. Returns error message or empty string.
~~ @param vm      the Wren VM handle
~~ @param module  name for this code module
~~ @param code    Wren source code to execute
function wren_try(vm: null, module: str, code: str) -> str native mocha_wren_safe_dostring;

~~ Evaluates a Wren expression and returns a float. Runs in the module of the last run call (default "main").
~~ @param vm    the Wren VM handle
~~ @param expr  Wren expression to evaluate
function wren_eval_number(vm: null, expr: str) -> float native mocha_wren_eval_number;

~~ Evaluates a Wren expression and returns a string. Runs in the module of the last run call (default "main").
~~ @param vm    the Wren VM handle
~~ @param expr  Wren expression to evaluate
function wren_eval_string(vm: null, expr: str) -> str native mocha_wren_eval_string;

~~ Evaluates a Wren expression and returns an int. Runs in the module of the last run call (default "main").
~~ @param vm    the Wren VM handle
~~ @param expr  Wren expression to evaluate
function wren_eval_int(vm: null, expr: str) -> int native mocha_wren_eval_int;

~~ Evaluates a Wren boolean expression and returns true or false. Runs in the module of the last run call (default "main").
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

~~ Calls a no-arg Wren static method, returns bool.
~~ @param vm         the Wren VM handle
~~ @param module     module where the class is defined
~~ @param classname  Wren class name
~~ @param sig        method signature e.g. "myMethod"
function wren_call_bool(vm: null, module: str, classname: str, sig: str) -> bool native mocha_wren_call_bool;

~~ Calls a Wren static method with 1 float arg, returns bool.
~~ @param vm         the Wren VM handle
~~ @param module     module where the class is defined
~~ @param classname  Wren class name
~~ @param sig        method signature e.g. "myMethod(_)"
~~ @param arg        numeric argument
function wren_call_bool_1n(vm: null, module: str, classname: str, sig: str, arg: float) -> bool native mocha_wren_call1n_bool;

~~ Calls a Wren static method with 1 float arg, returns str.
~~ @param vm         the Wren VM handle
~~ @param module     module where the class is defined
~~ @param classname  Wren class name
~~ @param sig        method signature e.g. "myMethod(_)"
~~ @param arg        numeric argument
function wren_call_string_1n(vm: null, module: str, classname: str, sig: str, arg: float) -> str native mocha_wren_call1n_string;