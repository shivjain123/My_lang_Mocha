from "mocha-lua" import *;

function lua_tests(didLoad) -> null {
    var ls: null = lua_open();

    print("--- Int truncation ---", newLine=true);

    lua_run(ls, "pos = 3.7");
    lua_run(ls, "neg = -3.7");
    lua_run(ls, "text = 'hello'");
    print("get_int(3.7): "     + str(lua_get_int(ls, "pos")), newLine=true);
    print("get_int(-3.7): "    + str(lua_get_int(ls, "neg")), newLine=true);
    print("get_int(missing): " + str(lua_get_int(ls, "nothing")), newLine=true);
    print("get_int(string): "  + str(lua_get_int(ls, "text")), newLine=true);

    lua_run(ls, "function give_pos() return 3.7 end");
    lua_run(ls, "function halve(n) return n / 2 end");
    print("call_int(3.7): "      + str(lua_call_int(ls, "give_pos")), newLine=true);
    print("call_int_1n(7/2): "   + str(lua_call_int_1n(ls, "halve", 7.0)), newLine=true);

    lua_close(ls);
    print("--- Done ---", newLine=true);
};