from "mocha-matvec" import *;

class Box {
    var n: int;
    function constructor() -> null {
        this.n = 0;
    };
    function bump() -> null {
        this.n = this.n + 5;
    };
};

function tst(didLoad) -> null {
    var b: Box = Box();
    b.bump();
};
