from "mocha-matvec" import *;

class Mix {
    var a: int;
    var b: float;
    var c: str;
    function constructor() -> null {
    };
};

class Box {
    var n: int;
    function constructor() -> null {
    };
};

class Empty {
    function constructor() -> null {
    };
};

function size_tests(didLoad) -> null {
    var m: Mix = Mix();
    var b: Box = Box();
    var e: Empty = Empty();
};
