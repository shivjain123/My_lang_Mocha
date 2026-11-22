from "mocha-matvec" import *;

class Zed {
    var a: int;
    var b: float;
    var c: bool;
    var d: str;
    var e: int[];
    function constructor() -> null {
        this.a = 5;
    };
};

function zero_tests(didLoad) -> null {
    var z: Zed = Zed();
};
