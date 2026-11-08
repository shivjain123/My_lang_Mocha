from "mocha-lua" import *;

function lua_tests(didLoad) -> null {
    var l: null = lua_open();
    lua_close(l);
    lua_close(l);
    print("still alive after double close", newLine=true);
};