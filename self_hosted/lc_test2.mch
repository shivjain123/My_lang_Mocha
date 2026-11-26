from "mocha-matvec" import *;

function lc_test2(didLoad) -> null {
    var a: int[] = [1, 2, 3, 4];
    var d: int[] = [x for each x in a if x > 2 else 0];
    print(d[0], newLine=true);
    print(d[3], newLine=true);
};
