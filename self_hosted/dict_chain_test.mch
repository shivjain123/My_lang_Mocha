from "mocha-matvec" import *;

function read_nested_int(d: dict) -> int {
    var x: int = d["a"]["b"];
    return x;
};

function read_nested_str(d: dict) -> str {
    var s: str = d["a"]["b"];
    return s;
};

function dict_tests(didLoad) -> null {
    print("ok", newLine=true);
};
