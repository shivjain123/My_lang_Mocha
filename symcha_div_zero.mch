from "mocha-math" import *;
function div(a: float, b: float) -> float {
    return a / b;
};

function main(didLoad) -> null {
    var zero: float = 0.0;
    var l: float = zero.log().real;
    print("1: ln(0) = ", l, "\n");
    var r: float = div(1.0, l);
    print("2: 1/ln(0) = ", r, "\n");
    var q: float = div(0.0, r);
    print("3: 0/(-0) = ", q, "\n");
};