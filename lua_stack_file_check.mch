from "mocha-lua" import *;

function lua_tests(didLoad) -> null {
    var l: null = lua_open();
    lua_run_file(l, "stack_check.lua");
    print("after file success, stack size (want 0):");
    print(lua_stack_size(l));
    lua_run_file(l, "no_such_file.lua");
    print("after file failure, stack size (want 0):");
    print(lua_stack_size(l));
    lua_close(l);
};