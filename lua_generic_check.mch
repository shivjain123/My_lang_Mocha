from "mocha-lua" import *;

function lua_tests(didLoad) -> null {
    var ls: null = lua_open();

    // ── 1. Mixed argument types ────────────────────────────────────
    print("--- 1. Mixed types ---", newLine=true);

    lua_run(ls, "function repeat_str(s, n) return string.rep(s, n) end");

    lua_begin_call(ls, "repeat_str");
    lua_push_string(ls, "ab");
    lua_push_int(ls, 3);
    print("repeat_str('ab', 3): " + lua_end_call_string(ls, 2), newLine=true);

    // ── 2. Three or more arguments ─────────────────────────────────
    print("--- 2. 3+ arguments ---", newLine=true);

    lua_run(ls, "function sum3(a, b, c) return a + b + c end");

    lua_begin_call(ls, "sum3");
    lua_push_number(ls, 1.5);
    lua_push_number(ls, 2.0);
    lua_push_number(ls, 3.0);
    print("sum3(1.5, 2.0, 3.0): " + str(lua_end_call_number(ls, 3)), newLine=true);

    lua_run(ls, "function describe(name, age, height, active) return name .. ':' .. age .. ':' .. height .. ':' .. tostring(active) end");

    lua_begin_call(ls, "describe");
    lua_push_string(ls, "Sam");
    lua_push_int(ls, 30);
    lua_push_number(ls, 1.75);
    lua_push_bool(ls, true);
    print("describe (4 mixed args): " + lua_end_call_string(ls, 4), newLine=true);

    // ── 3. Int and bool returns ────────────────────────────────────
    print("--- 3. Int and bool returns ---", newLine=true);

    lua_run(ls, "function count_true(a, b, c) local n = 0 if a then n = n + 1 end if b then n = n + 1 end if c then n = n + 1 end return n end");
    lua_run(ls, "function all_positive(a, b, c) return a > 0 and b > 0 and c > 0 end");

    lua_begin_call(ls, "count_true");
    lua_push_bool(ls, true);
    lua_push_bool(ls, false);
    lua_push_bool(ls, true);
    print("count_true(true,false,true): " + str(lua_end_call_int(ls, 3)), newLine=true);

    lua_begin_call(ls, "all_positive");
    lua_push_number(ls, 1.0);
    lua_push_number(ls, 2.0);
    lua_push_number(ls, 3.0);
    print("all_positive(1,2,3): " + str(lua_end_call_bool(ls, 3)), newLine=true);

    lua_begin_call(ls, "all_positive");
    lua_push_number(ls, 1.0);
    lua_push_number(ls, -2.0);
    lua_push_number(ls, 3.0);
    print("all_positive(1,-2,3): " + str(lua_end_call_bool(ls, 3)), newLine=true);

    // ── 4. Zero arguments through the generic path ─────────────────
    print("--- 4. Zero arguments ---", newLine=true);

    lua_run(ls, "function get_seven() return 7 end");
    lua_begin_call(ls, "get_seven");
    print("get_seven: " + str(lua_end_call_int(ls, 0)), newLine=true);

    // ── 5. Error recovery ──────────────────────────────────────────
    print("--- 5. Error recovery ---", newLine=true);

    lua_clear_stack(ls);
    print("end_call without begin: " + str(lua_end_call_int(ls, 0)), newLine=true);

    lua_begin_call(ls, "sum3");
    lua_push_number(ls, 1.0);
    print("wrong arg count: " + str(lua_end_call_number(ls, 3)), newLine=true);
    lua_clear_stack(ls);

    lua_begin_call(ls, "no_such_func");
    lua_push_number(ls, 1.0);
    print("missing function: " + str(lua_end_call_number(ls, 1)), newLine=true);

    lua_run(ls, "still_ok = 'still alive!'");
    print("after errors: " + lua_get_string(ls, "still_ok"), newLine=true);

    lua_close(ls);
    print("--- Lua generic Done ---", newLine=true);
};