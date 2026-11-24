from "mocha-matvec" import *;

class K {
    function a() -> int {
        return this.b();
    };
    function b() -> int {
        return 1;
    };
};

function early(didLoad) -> null {
    var x: int = later(2);
    var k: K = K();
    var y: int = k.a();
};

function later(n: int) -> int {
    return n + 1;
};
