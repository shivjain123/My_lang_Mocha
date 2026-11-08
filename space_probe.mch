from "mocha-space" import *;

function space_probe(didLoad) -> null {
    var got: float = 254.039;
    var expected: float = 253.67;
    var diff: float = got - expected;
    print("diff = " + str(diff), newLine=true);
    var top: float = abs(diff);
    print("top = " + str(top), newLine=true);
    var bottom: float = abs(expected);
    print("bottom = " + str(bottom), newLine=true);
    var rel: float = top / bottom;
    print("rel = " + str(rel), newLine=true);
};