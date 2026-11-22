from "mocha-matvec" import *;

function empty_array_tests(didLoad) -> null {
    var a: int[] = [];
    a.push(5);
    a.push(6);
    a[0] = 7;
    var b: int[] = [1];
    b = [];
    b.push(9);
    var c: bool[] = [];
    print(str(a[0]) + " " + str(b[0]), newLine=true);
};
