from "mocha-matvec" import *;

function make_tuple() -> (int, 2) {
    var t: (int, 2) = (7, 8);
    return t;
};

function box_tests(didLoad) -> null {
    var a: int[] = [1];
    a.push(5);
    var v: vast[] = [1];
    var t: (int, 2) = make_tuple();
    var x: int = t#1;
};
