from "mocha-lua" import *;

function lua_tests(didLoad) -> null {
    var ls: null = lua_open();

    // ── 1. Get values ──────────────────────────────────────────────
    print("--- 1. Get values ---", newLine=true);

    lua_run(ls, "n = 42.5");
    print("get_number: " + str(lua_get_number(ls, "n")), newLine=true);

    lua_run(ls, "s = 'hello from Lua'");
    print("get_string: " + lua_get_string(ls, "s"), newLine=true);

    lua_run(ls, "b = true");
    print("get_bool: " + str(lua_get_bool(ls, "b")), newLine=true);

    lua_run(ls, "i = 99");
    print("get_int: " + str(lua_get_int(ls, "i")), newLine=true);

    // ── 2. Set values ──────────────────────────────────────────────
    print("--- 2. Set values ---", newLine=true);

    lua_set_number(ls, "x", 3.14);
    lua_run(ls, "result = x * 2");
    print("set_number: x=3.14, x*2=" + str(lua_get_number(ls, "result")), newLine=true);

    lua_set_string(ls, "name", "Mocha");
    lua_run(ls, "greeting = 'Hello, ' .. name .. '!'");
    print("set_string: " + lua_get_string(ls, "greeting"), newLine=true);

    lua_set_bool(ls, "flag", true);
    lua_run(ls, "if flag then flag_str = 'yes' else flag_str = 'no' end");
    print("set_bool: flag=" + lua_get_string(ls, "flag_str"), newLine=true);

    lua_set_int(ls, "count", 5);
    lua_run(ls, "doubled = count * 2");
    print("set_int: count=5, doubled=" + str(lua_get_int(ls, "doubled")), newLine=true);

    // ── 3. Bidirectional ───────────────────────────────────────────
    print("--- 3. Bidirectional ---", newLine=true);

    lua_set_number(ls, "a", 10.0);
    lua_set_number(ls, "b", 20.0);
    lua_set_number(ls, "c", 30.0);
    lua_run(ls, "avg = (a + b + c) / 3");
    print("avg of 10,20,30 in Lua: " + str(lua_get_number(ls, "avg")), newLine=true);

    lua_set_string(ls, "input", "hello world");
    lua_run(ls, "upper_result = string.upper(input)");
    print("string.upper: " + lua_get_string(ls, "upper_result"), newLine=true);

    // ── 4. Protected execution ─────────────────────────────────────
    print("--- 4. lua_try ---", newLine=true);

    var ok_result: str = lua_try(ls, "safe_val = 42");
    print("valid code error: '" + ok_result + "'", newLine=true);

    var err: str = lua_try(ls, "this is not valid lua !@#$");
    print("invalid code error: " + err, newLine=true);

    // ── 5. Stack ───────────────────────────────────────────────────
    print("--- 5. Stack ---", newLine=true);

    print("stack size: " + str(lua_stack_size(ls)), newLine=true);
    lua_clear_stack(ls);
    print("after clear: " + str(lua_stack_size(ls)), newLine=true);

    // ── 6. Call Lua functions ──────────────────────────────────────
    print("--- 6. Call functions ---", newLine=true);

    lua_run(ls, "function get_pi() return 3.14159 end");
    lua_run(ls, "function get_greeting() return 'Hello from Lua!' end");
    lua_run(ls, "function get_answer() return 42 end");
    lua_run(ls, "function double_it(n) return n * 2 end");
    lua_run(ls, "function shout(s) return string.upper(s) .. '!!!' end");
    lua_run(ls, "function add(a, b) return a + b end");
    lua_run(ls, "function concat(a, b) return a .. ' ' .. b end");

    print("get_pi: "      + str(lua_call_number(ls, "get_pi")), newLine=true);
    print("get_greeting: " + lua_call_string(ls, "get_greeting"), newLine=true);
    print("get_answer: "  + str(lua_call_int(ls, "get_answer")), newLine=true);

    print("double_it(5): "      + str(lua_call_number_1n(ls, "double_it", 5.0)), newLine=true);
    print("shout('mocha'): "    + lua_call_string_1s(ls, "shout", "mocha"), newLine=true);
    print("add(3,4): "          + str(lua_call_number_2n(ls, "add", 3.0, 4.0)), newLine=true);
    print("concat: "            + lua_call_string_2s(ls, "concat", "hello", "world"), newLine=true);

    // ── 7. Real use case — FizzBuzz in Lua ────────────────────────
    print("--- 7. FizzBuzz ---", newLine=true);

    lua_run(ls, "function fizzbuzz(n) n=math.floor(n) if n%15==0 then return 'FizzBuzz' elseif n%3==0 then return 'Fizz' elseif n%5==0 then return 'Buzz' else return tostring(math.floor(n)) end end");

    var i: int = 1;
    while (i <= 15) {
        print(lua_call_string_1n(ls, "fizzbuzz", float(i)) + " ");
        i++;
    };
    print("", newLine=true);

    // ── 8. Error recovery ──────────────────────────────────────────
    print("--- 8. Error recovery ---", newLine=true);

    var e1: str = lua_try(ls, "error('deliberate crash!')");
    print("caught: " + e1, newLine=true);

    lua_run(ls, "recovered = 'still alive!'");
    print("after error: " + lua_get_string(ls, "recovered"), newLine=true);

    lua_close(ls);
    print("--- Lua FFI Done ---", newLine=true);
};