from "mocha-lua" import *;

function lua_tests(didLoad) -> null {
    var l: null = lua_open();
    lua_run(l, "function bad() error('boom') end");
    lua_run(l, "function zero() return 0 end");
    var a: float = lua_call_number(l, "zero");
    print("real zero, failed? (want false):");
    print(lua_call_failed(l));
    var b: float = lua_call_number(l, "bad");
    print("error call, failed? (want true):");
    print(lua_call_failed(l));
    print("error message (want something with boom):");
    print(lua_call_error(l));
    var c: float = lua_call_number(l, "zero");
    print("real zero again, failed? (want false):");
    print(lua_call_failed(l));
    lua_close(l);
};