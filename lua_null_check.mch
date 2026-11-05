from "mocha-lua" import *;

function lua_tests(didLoad) -> null {
    var ls: null = lua_open();
    lua_close(ls);
    var dead: null = null;

    print("--- Null state guards ---", newLine=true);

    print("run: "       + str(lua_run(dead, "x = 1")), newLine=true);
    print("get_number: " + str(lua_get_number(dead, "x")), newLine=true);
    print("get_string: '" + lua_get_string(dead, "x") + "'", newLine=true);
    print("get_int: "   + str(lua_get_int(dead, "x")), newLine=true);
    print("try: "       + lua_try(dead, "x = 1"), newLine=true);
    print("call_number: " + str(lua_call_number(dead, "f")), newLine=true);
    print("call_bool_2s: " + str(lua_call_bool_2s(dead, "f", "a", "b")), newLine=true);
    print("end_call_int: " + str(lua_end_call_int(dead, 0)), newLine=true);

    print("--- Done ---", newLine=true);
};