// ── FFI declarations ──

function lua_new() -> null native mocha_lua_new;
function lua_close(lua: null) -> null native mocha_lua_close;
function lua_dostring(lua: null, code: str) -> int native mocha_lua_dostring;
function lua_dofile(lua: null, filename: str) -> int native mocha_lua_dofile;
function lua_getnumber(lua: null, varname: str) -> float native mocha_lua_getnumber;
function lua_getstring(lua: null, varname: str) -> str native mocha_lua_getstring;
function lua_getbool(lua: null, varname: str) -> bool native mocha_lua_getbool;
function lua_getint(lua: null, varname: str) -> int native mocha_lua_getint;
function lua_setnumber(lua: null, varname: str, val: float) -> null native mocha_lua_setnumber;
function lua_setstring(lua: null, varname: str, val: str) -> null native mocha_lua_setstring;
function lua_setbool(lua: null, varname: str, val: bool) -> null native mocha_lua_setbool;
function lua_setint(lua: null, varname: str, val: int) -> null native mocha_lua_setint;
function lua_safe_dostring(lua: null, code: str) -> str native mocha_lua_safe_dostring;
function lua_stack_size(lua: null) -> int native mocha_lua_stack_size;
function lua_clear_stack(lua: null) -> null native mocha_lua_clear_stack;
function lua_call_number(lua: null, funcname: str) -> float native mocha_lua_call_number;
function lua_call_string(lua: null, funcname: str) -> str native mocha_lua_call_string;
function lua_call_int(lua: null, funcname: str) -> int native mocha_lua_call_int;
function lua_call1n_number(lua: null, funcname: str, arg: float) -> float native mocha_lua_call1n_number;
function lua_call1s_string(lua: null, funcname: str, arg: str) -> str native mocha_lua_call1s_string;
function lua_call2n_number(lua: null, funcname: str, a: float, b: float) -> float native mocha_lua_call2n_number;
function lua_call2s_string(lua: null, funcname: str, a: str, b: str) -> str native mocha_lua_call2s_string;
function lua_call1n_string(lua: null, funcname: str, arg: float) -> str native mocha_lua_call1n_string;

function lua_tests(didLoad) -> null {
    var ls: null = lua_new();

    // ══════════════════════════════════════════
    // SECTION 1 — Get values (existing)
    // ══════════════════════════════════════════
    print("--- 1. Get values ---", newLine=true);

    lua_dostring(ls, "n = 42.5");
    print("getnumber: " + str(lua_getnumber(ls, "n")), newLine=true);  // 42.5

    lua_dostring(ls, "s = 'hello from Lua'");
    print("getstring: " + lua_getstring(ls, "s"), newLine=true);  // hello from Lua

    lua_dostring(ls, "b = true");
    print("getbool: " + str(lua_getbool(ls, "b")), newLine=true);  // true

    lua_dostring(ls, "i = 99");
    print("getint: " + str(lua_getint(ls, "i")), newLine=true);  // 99

    // ══════════════════════════════════════════
    // SECTION 2 — Set values from Mocha into Lua
    // ══════════════════════════════════════════
    print("--- 2. Set values ---", newLine=true);

    // set a number and use it in Lua
    lua_setnumber(ls, "x", 3.14);
    lua_dostring(ls, "result = x * 2");
    print("setnumber: x=3.14, x*2=" + str(lua_getnumber(ls, "result")), newLine=true);  // 6.28

    // set a string and use it in Lua
    lua_setstring(ls, "name", "Mocha");
    lua_dostring(ls, "greeting = 'Hello, ' .. name .. '!'");
    print("setstring: " + lua_getstring(ls, "greeting"), newLine=true);  // Hello, Mocha!

    // set a bool and use it in Lua
    lua_setbool(ls, "flag", true);
    lua_dostring(ls, "if flag then flag_str = 'yes' else flag_str = 'no' end");
    print("setbool: flag=" + lua_getstring(ls, "flag_str"), newLine=true);  // yes

    // set an int and use it in Lua
    lua_setint(ls, "count", 5);
    lua_dostring(ls, "doubled = count * 2");
    print("setint: count=5, doubled=" + str(lua_getint(ls, "doubled")), newLine=true);  // 10

    // ══════════════════════════════════════════
    // SECTION 3 — Bidirectional data flow
    // ══════════════════════════════════════════
    print("--- 3. Bidirectional ---", newLine=true);

    // pass array of numbers from Mocha, process in Lua, get result back
    lua_setnumber(ls, "a", 10.0);
    lua_setnumber(ls, "b", 20.0);
    lua_setnumber(ls, "c", 30.0);
    lua_dostring(ls, "avg = (a + b + c) / 3");
    print("avg of 10,20,30 in Lua: " + str(lua_getnumber(ls, "avg")), newLine=true);  // 20.0

    // pass a string from Mocha, process in Lua, get back
    lua_setstring(ls, "input", "hello world");
    lua_dostring(ls, "upper_result = string.upper(input)");
    print("Lua string.upper: " + lua_getstring(ls, "upper_result"), newLine=true);  // HELLO WORLD

    // ══════════════════════════════════════════
    // SECTION 4 — Protected execution
    // ══════════════════════════════════════════
    print("--- 4. Safe dostring ---", newLine=true);

    // valid code — should return empty string
    var ok_result: str = lua_safe_dostring(ls, "safe_val = 42");
    print("valid code error: '" + ok_result + "'", newLine=true);  // ''

    // invalid code — should return error message
    var err: str = lua_safe_dostring(ls, "this is not valid lua !@#$");
    print("invalid code error: " + err, newLine=true);  // some error message

    // ══════════════════════════════════════════
    // SECTION 5 — Stack utilities
    // ══════════════════════════════════════════
    print("--- 5. Stack ---", newLine=true);

    print("stack size (clean): " + str(lua_stack_size(ls)), newLine=true);  // 0
    lua_clear_stack(ls);
    print("stack after clear: " + str(lua_stack_size(ls)), newLine=true);   // 0

    // ══════════════════════════════════════════
    // SECTION 6 — Call Lua functions from Mocha
    // ══════════════════════════════════════════
    print("--- 6. Call Lua functions ---", newLine=true);

    // define Lua functions
    lua_dostring(ls, "function get_pi() return 3.14159 end");
    lua_dostring(ls, "function get_greeting() return 'Hello from Lua function!' end");
    lua_dostring(ls, "function get_answer() return 42 end");
    lua_dostring(ls, "function double_it(n) return n * 2 end");
    lua_dostring(ls, "function shout(s) return string.upper(s) .. '!!!' end");
    lua_dostring(ls, "function add(a, b) return a + b end");
    lua_dostring(ls, "function concat(a, b) return a .. ' ' .. b end");

    // call with no args
    print("call_number get_pi: " + str(lua_call_number(ls, "get_pi")), newLine=true);        // 3.14159
    print("call_string get_greeting: " + lua_call_string(ls, "get_greeting"), newLine=true); // Hello from Lua function!
    print("call_int get_answer: " + str(lua_call_int(ls, "get_answer")), newLine=true);      // 42

    // call with one arg
    print("call1n double_it(5): " + str(lua_call1n_number(ls, "double_it", 5.0)), newLine=true);      // 10.0
    print("call1s shout('mocha'): " + lua_call1s_string(ls, "shout", "mocha"), newLine=true);         // MOCHA!!!

    // call with two args
    print("call2n add(3,4): " + str(lua_call2n_number(ls, "add", 3.0, 4.0)), newLine=true);           // 7.0
    print("call2s concat('hello','world'): " + lua_call2s_string(ls, "concat", "hello", "world"), newLine=true); // hello world

    // ══════════════════════════════════════════
    // SECTION 7 — Real use case
    // Mocha generates data, Lua processes it
    // ══════════════════════════════════════════
    print("--- 7. Real use case ---", newLine=true);

    // define a Lua function that does something non-trivial
    lua_dostring(ls, "function fizzbuzz(n) n=math.floor(n) if n%15==0 then return 'FizzBuzz' elseif n%3==0 then return 'Fizz' elseif n%5==0 then return 'Buzz' else return tostring(math.floor(n)) end end");

    // call it from Mocha in a loop
    var i: int = 1;
    while (i <= 15) {
        var fz: str = lua_call1n_string(ls, "fizzbuzz", float(i));
        print(fz + " ");
        i++;
    };
    print("", newLine=true);

    // ══════════════════════════════════════════
    // SECTION 8 — Lua error recovery
    // ══════════════════════════════════════════
    print("--- 8. Error recovery ---", newLine=true);

    // crash Lua code safely, then continue normally
    var e1: str = lua_safe_dostring(ls, "error('deliberate crash!')");
    print("caught error: " + e1, newLine=true);

    // Lua state still usable after safe error
    lua_dostring(ls, "recovered = 'still alive!'");
    print("after error: " + lua_getstring(ls, "recovered"), newLine=true);  // still alive!

    lua_close(ls);
    print("--- Lua FFI v2 Done ---", newLine=true);
};