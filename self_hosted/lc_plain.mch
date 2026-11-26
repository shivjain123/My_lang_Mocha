from "mocha-matvec" import *;

function lc_plain(didLoad) -> null {
    var a: int[] = [1, 2, 3, 4];
    var c: int[] = [x + 1 for each x in a];
    print(c.length, newLine=true);
    print(c[3], newLine=true);
};
