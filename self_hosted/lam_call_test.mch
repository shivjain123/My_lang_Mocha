from "mocha-matvec" import *;

function apply(pred: lambda, x: int) -> int {
    var r: int = pred(x);
    return r;
};

function lam_call_test(didLoad) -> null {
    var k: int = 5;
    var a: int = apply(lambda(v: int) -> int: v + 1, 3);
    var b: int = apply(lambda(v: int) -> int: v + k, 3);
    print(a, newLine=true);
    print(b, newLine=true);
};
