from "mocha-lua" import *;

function lua_tests(didLoad) -> null {
    var l: null = lua_open();
    lua_run(l, "function add(a, b) return a + b end");
    lua_begin_call(l, "add");
    lua_push_number(l, 2.0);
    lua_push_number(l, 3.0);
    var r: float = lua_end_call_number(l, 2);
    print("good generic call, result (want 5) and failed? (want false):", newLine=true);
    print(r, newLine=true);
    print(lua_call_failed(l), newLine=true);
    var bad: float = lua_end_call_number(l, 2);
    print("no begin_call, failed? (want true):", newLine=true);
    print(lua_call_failed(l), newLine=true);
    print("stack size after (want 0):", newLine=true);
    print(lua_stack_size(l), newLine=true);
    lua_close(l);
};