~~ Mocha-Lua FFI Library
~~ Provides bidirectional Lua integration for Mocha programs.
~~ Use lua_open() to create a Lua state and lua_close() to destroy it.

~~ Creates a new Lua state. Returns an opaque handle.
function lua_open() -> null native mocha_lua_new;

~~ Closes and destroys a Lua state.
~~ @param lua  the Lua state handle
function lua_close(lua: null) -> null native mocha_lua_close;

~~ Runs a Lua code string. Returns 0 on success.
~~ @param lua   the Lua state handle
~~ @param code  Lua source code to execute
function lua_run(lua: null, code: str) -> int native mocha_lua_dostring;

~~ Runs a Lua file. Returns 0 on success.
~~ @param lua       the Lua state handle
~~ @param filename  path to the .lua file
function lua_run_file(lua: null, filename: str) -> int native mocha_lua_dofile;

~~ Runs a Lua code string safely. Returns error message or empty string.
~~ @param lua   the Lua state handle
~~ @param code  Lua source code to execute
function lua_try(lua: null, code: str) -> str native mocha_lua_safe_dostring;

~~ Gets a numeric variable from Lua global scope.
~~ @param lua   the Lua state handle
~~ @param name  variable name in Lua
function lua_get_number(lua: null, name: str) -> float native mocha_lua_getnumber;

~~ Gets a string variable from Lua global scope.
~~ @param lua   the Lua state handle
~~ @param name  variable name in Lua
function lua_get_string(lua: null, name: str) -> str native mocha_lua_getstring;

~~ Gets a boolean variable from Lua global scope.
~~ @param lua   the Lua state handle
~~ @param name  variable name in Lua
function lua_get_bool(lua: null, name: str) -> bool native mocha_lua_getbool;

~~ Gets an integer variable from Lua global scope.
~~ @param lua   the Lua state handle
~~ @param name  variable name in Lua
function lua_get_int(lua: null, name: str) -> int native mocha_lua_getint;

~~ Sets a numeric variable in Lua global scope.
~~ @param lua   the Lua state handle
~~ @param name  variable name in Lua
~~ @param val   value to set
function lua_set_number(lua: null, name: str, val: float) -> null native mocha_lua_setnumber;

~~ Sets a string variable in Lua global scope.
~~ @param lua   the Lua state handle
~~ @param name  variable name in Lua
~~ @param val   value to set
function lua_set_string(lua: null, name: str, val: str) -> null native mocha_lua_setstring;

~~ Sets a boolean variable in Lua global scope.
~~ @param lua   the Lua state handle
~~ @param name  variable name in Lua
~~ @param val   value to set
function lua_set_bool(lua: null, name: str, val: bool) -> null native mocha_lua_setbool;

~~ Sets an integer variable in Lua global scope.
~~ @param lua   the Lua state handle
~~ @param name  variable name in Lua
~~ @param val   value to set
function lua_set_int(lua: null, name: str, val: int) -> null native mocha_lua_setint;

~~ Returns the current Lua stack size.
~~ @param lua  the Lua state handle
function lua_stack_size(lua: null) -> int native mocha_lua_stack_size;

~~ Clears the Lua stack.
~~ @param lua  the Lua state handle
function lua_clear_stack(lua: null) -> null native mocha_lua_clear_stack;

~~ Calls a no-arg Lua function, returns float.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
function lua_call_number(lua: null, func: str) -> float native mocha_lua_call_number;

~~ Calls a no-arg Lua function, returns str.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
function lua_call_string(lua: null, func: str) -> str native mocha_lua_call_string;

~~ Calls a no-arg Lua function, returns int.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
function lua_call_int(lua: null, func: str) -> int native mocha_lua_call_int;

~~ Calls a Lua function with 1 float arg, returns float.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
~~ @param arg   numeric argument
function lua_call_number_1n(lua: null, func: str, arg: float) -> float native mocha_lua_call1n_number;

~~ Calls a Lua function with 1 str arg, returns str.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
~~ @param arg   string argument
function lua_call_string_1s(lua: null, func: str, arg: str) -> str native mocha_lua_call1s_string;

~~ Calls a Lua function with 2 float args, returns float.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
~~ @param a     first numeric argument
~~ @param b     second numeric argument
function lua_call_number_2n(lua: null, func: str, a: float, b: float) -> float native mocha_lua_call2n_number;

~~ Calls a Lua function with 2 str args, returns str.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
~~ @param a     first string argument
~~ @param b     second string argument
function lua_call_string_2s(lua: null, func: str, a: str, b: str) -> str native mocha_lua_call2s_string;

~~ Calls a Lua function with 1 float arg, returns str.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
~~ @param arg   numeric argument
function lua_call_string_1n(lua: null, func: str, arg: float) -> str native mocha_lua_call1n_string;