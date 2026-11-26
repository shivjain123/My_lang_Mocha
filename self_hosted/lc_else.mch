from "mocha-matvec" import *;

function lc_else(didLoad) -> null {
    var a: int[] = [1, 2, 3, 4];
    var d: int[] = [x if x > 2 else 0 for each x in a];
    print(d[0], newLine=true);
    print(d[3], newLine=true);
};
