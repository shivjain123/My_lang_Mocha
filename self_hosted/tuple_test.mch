from "mocha-matvec" import *;

function tuple_tests(didLoad) -> null {
    var m: (int, 3) = (1, 2, 3);
    var a: int = m#0;
    var h: (float, 3) = (1.5, 2.5, 3.5);
    var g: float = h#2;
    var w: (str, 2) = ("x", "y");
    var s: str = w#1;
};
