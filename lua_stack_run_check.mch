from "mocha-lua" import *;

function lua_tests(didLoad) -> null {
    var l: null = lua_open();
    lua_run(l, "return 1, 2, 3");
    print("after success, stack size (want 0):");
    print(lua_stack_size(l));
    lua_run(l, "this is not lua");
    print("after failure, stack size (want 0):");
    print(lua_stack_size(l));
    lua_close(l);
};