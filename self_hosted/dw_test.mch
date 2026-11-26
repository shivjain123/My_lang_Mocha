from "mocha-matvec" import *;

function dw_test(didLoad) -> null {
    var d: dict = {"a": 1};
    d["b"] = 5;
    d["a"] = 7;
    d["s"] = "hi";
    var x: int = d["b"];
    var y: int = d["a"];
    var z: str = d["s"];
    print(x, newLine=true);
    print(y, newLine=true);
    print(z, newLine=true);
};
