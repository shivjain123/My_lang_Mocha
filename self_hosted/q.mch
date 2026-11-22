from "mocha-matvec" import *;

class Box {
    var n: int;
    function constructor() -> null {
        this.n = 0;
    };
};

function tst(didLoad) -> null {
    var b: Box = Box();
    var k: int = b.n;
};

