from "mocha-matvec" import *;

function lc_test(didLoad) -> null {
    var a: int[] = [1, 2, 3, 4];
    var b: int[] = [x * 2 for each x in a if x > 1];
    var c: int[] = [x + 1 for each x in a];
    print(b.length, newLine=true);
    print(b[0], newLine=true);
    print(c[3], newLine=true);
};
