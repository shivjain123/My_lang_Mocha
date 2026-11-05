from "mocha-lua" import *;

function lua_tests(didLoad) -> null {
    var ls: null = lua_open();

    // ── 1. Bool returns ────────────────────────────────────────────
    print("--- 1. Bool returns ---", newLine=true);

    lua_run(ls, "function get_true() return true end");
    lua_run(ls, "function get_false() return false end");
    lua_run(ls, "function is_positive(n) return n > 0 end");
    lua_run(ls, "function is_empty(s) return s == '' end");
    lua_run(ls, "function both_positive(a, b) return a > 0 and b > 0 end");
    lua_run(ls, "function same_string(a, b) return a == b end");

    print("get_true: "  + str(lua_call_bool(ls, "get_true")), newLine=true);
    print("get_false: " + str(lua_call_bool(ls, "get_false")), newLine=true);

    print("is_positive(5): "  + str(lua_call_bool_1n(ls, "is_positive", 5.0)), newLine=true);
    print("is_positive(-5): " + str(lua_call_bool_1n(ls, "is_positive", -5.0)), newLine=true);

    print("is_empty(''): "   + str(lua_call_bool_1s(ls, "is_empty", "")), newLine=true);
    print("is_empty('hi'): " + str(lua_call_bool_1s(ls, "is_empty", "hi")), newLine=true);

    print("both_positive(3,4): "  + str(lua_call_bool_2n(ls, "both_positive", 3.0, 4.0)), newLine=true);
    print("both_positive(3,-4): " + str(lua_call_bool_2n(ls, "both_positive", 3.0, -4.0)), newLine=true);

    print("same_string(a,a): " + str(lua_call_bool_2s(ls, "same_string", "a", "a")), newLine=true);
    print("same_string(a,b): " + str(lua_call_bool_2s(ls, "same_string", "a", "b")), newLine=true);

    // ── 2. Int returns with arguments ──────────────────────────────
    print("--- 2. Int returns ---", newLine=true);

    lua_run(ls, "function floor_it(n) return math.floor(n) end");
    lua_run(ls, "function str_len(s) return #s end");
    lua_run(ls, "function add_int(a, b) return math.floor(a + b) end");
    lua_run(ls, "function total_len(a, b) return #a + #b end");

    print("floor_it(7.9): "       + str(lua_call_int_1n(ls, "floor_it", 7.9)), newLine=true);
    print("str_len('mocha'): "    + str(lua_call_int_1s(ls, "str_len", "mocha")), newLine=true);
    print("add_int(3,4): "        + str(lua_call_int_2n(ls, "add_int", 3.0, 4.0)), newLine=true);
    print("total_len('ab','cde'): " + str(lua_call_int_2s(ls, "total_len", "ab", "cde")), newLine=true);

    // ── 3. Error recovery ──────────────────────────────────────────
    print("--- 3. Error recovery ---", newLine=true);

    print("missing function (bool): " + str(lua_call_bool(ls, "no_such_func")), newLine=true);
    print("missing function (int): "  + str(lua_call_int_1n(ls, "no_such_func", 1.0)), newLine=true);

    lua_run(ls, "still_ok = 'still alive!'");
    print("after errors: " + lua_get_string(ls, "still_ok"), newLine=true);

    lua_close(ls);
    print("--- Lua bool/int Done ---", newLine=true);
};