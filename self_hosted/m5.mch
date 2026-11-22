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

function t5(didLoad) -> null {
    var b: Box = Box();
    b.bump();
    b.n = 9;
};
