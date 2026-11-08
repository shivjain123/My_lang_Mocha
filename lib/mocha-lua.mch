~~ Mocha-Lua FFI Library
~~ Provides bidirectional Lua integration for Mocha programs.
~~ Use lua_open() to create a Lua state and lua_close() to destroy it.

~~ Creates a new Lua state. Returns an opaque handle.
function lua_open() -> null native mocha_lua_new;

~~ Closes and destroys a Lua state. Closing the same handle twice is safe:
~~ the second close prints a warning and is ignored.
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
~~ A missing or non-numeric global gives 0.0.
~~ @param lua   the Lua state handle
~~ @param name  variable name in Lua
function lua_get_number(lua: null, name: str) -> float native mocha_lua_getnumber;

~~ Gets a string variable from Lua global scope.
~~ A missing or non-string global gives an empty string.
~~ @param lua   the Lua state handle
~~ @param name  variable name in Lua
function lua_get_string(lua: null, name: str) -> str native mocha_lua_getstring;

~~ Gets a boolean variable from Lua global scope.
~~ Lua rules apply: only nil and false give false, so a missing global gives false,
~~ while 0 and an empty string give true.
~~ @param lua   the Lua state handle
~~ @param name  variable name in Lua
function lua_get_bool(lua: null, name: str) -> bool native mocha_lua_getbool;

~~ Gets an integer variable from Lua global scope.
~~ Decimals are cut off (3.7 gives 3). A missing or non-numeric global gives 0.
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

~~ Calls a no-arg Lua function, returns bool.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
function lua_call_bool(lua: null, func: str) -> bool native mocha_lua_call_bool;

~~ Calls a Lua function with 1 float arg, returns bool.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
~~ @param arg   numeric argument
function lua_call_bool_1n(lua: null, func: str, arg: float) -> bool native mocha_lua_call1n_bool;

~~ Calls a Lua function with 1 str arg, returns bool.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
~~ @param arg   string argument
function lua_call_bool_1s(lua: null, func: str, arg: str) -> bool native mocha_lua_call1s_bool;

~~ Calls a Lua function with 2 float args, returns bool.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
~~ @param a     first numeric argument
~~ @param b     second numeric argument
function lua_call_bool_2n(lua: null, func: str, a: float, b: float) -> bool native mocha_lua_call2n_bool;

~~ Calls a Lua function with 2 str args, returns bool.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
~~ @param a     first string argument
~~ @param b     second string argument
function lua_call_bool_2s(lua: null, func: str, a: str, b: str) -> bool native mocha_lua_call2s_bool;

~~ Calls a Lua function with 1 float arg, returns int.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
~~ @param arg   numeric argument
function lua_call_int_1n(lua: null, func: str, arg: float) -> int native mocha_lua_call1n_int;

~~ Calls a Lua function with 1 str arg, returns int.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
~~ @param arg   string argument
function lua_call_int_1s(lua: null, func: str, arg: str) -> int native mocha_lua_call1s_int;

~~ Calls a Lua function with 2 float args, returns int.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
~~ @param a     first numeric argument
~~ @param b     second numeric argument
function lua_call_int_2n(lua: null, func: str, a: float, b: float) -> int native mocha_lua_call2n_int;

~~ Calls a Lua function with 2 str args, returns int.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
~~ @param a     first string argument
~~ @param b     second string argument
function lua_call_int_2s(lua: null, func: str, a: str, b: str) -> int native mocha_lua_call2s_int;

~~ ── Generic calls: any number of args, any mix of types ──
~~ Usage: lua_begin_call(lua, "name"), then one lua_push_* per argument in order,
~~ then lua_end_call_<return>(lua, number_of_args) to run it and get the result.
~~ Pass the same count you pushed. A wrong count or a missing begin prints a MochaLuaError
~~ and makes the call fail (check it with lua_call_failed, see the end of this file).

~~ Starts a call: selects the Lua function to call.
~~ @param lua   the Lua state handle
~~ @param func  name of the Lua function
function lua_begin_call(lua: null, func: str) -> null native mocha_lua_begin_call;

~~ Adds a float argument to the pending call.
~~ @param lua  the Lua state handle
~~ @param val  numeric argument
function lua_push_number(lua: null, val: float) -> null native mocha_lua_push_number;

~~ Adds a str argument to the pending call.
~~ @param lua  the Lua state handle
~~ @param val  string argument
function lua_push_string(lua: null, val: str) -> null native mocha_lua_push_string;

~~ Adds an int argument to the pending call.
~~ @param lua  the Lua state handle
~~ @param val  integer argument
function lua_push_int(lua: null, val: int) -> null native mocha_lua_push_int;

~~ Adds a bool argument to the pending call.
~~ @param lua  the Lua state handle
~~ @param val  boolean argument
function lua_push_bool(lua: null, val: bool) -> null native mocha_lua_push_bool;

~~ Runs the pending call and returns a float.
~~ @param lua    the Lua state handle
~~ @param nargs  how many arguments were pushed
function lua_end_call_number(lua: null, nargs: int) -> float native mocha_lua_end_call_number;

~~ Runs the pending call and returns a str.
~~ @param lua    the Lua state handle
~~ @param nargs  how many arguments were pushed
function lua_end_call_string(lua: null, nargs: int) -> str native mocha_lua_end_call_string;

~~ Runs the pending call and returns an int.
~~ @param lua    the Lua state handle
~~ @param nargs  how many arguments were pushed
function lua_end_call_int(lua: null, nargs: int) -> int native mocha_lua_end_call_int;

~~ Runs the pending call and returns a bool.
~~ @param lua    the Lua state handle
~~ @param nargs  how many arguments were pushed
function lua_end_call_bool(lua: null, nargs: int) -> bool native mocha_lua_end_call_bool;

~~ ── Checking if a call failed ──
~~ After any lua_call_* or lua_end_call_* you can ask if it failed.
~~ A failed call still returns 0, 0.0 or "", so use these to tell it apart from a real zero.
~~ The status belongs to the Lua state and is updated by every call.

~~ Did the last lua_call_* or lua_end_call_* fail? Returns true if it did.
~~ @param lua  the Lua state handle
function lua_call_failed(lua: null) -> bool native mocha_lua_call_failed;

~~ Gets the error message of the last failed call, or an empty string.
~~ @param lua  the Lua state handle
function lua_call_error(lua: null) -> str native mocha_lua_call_error;