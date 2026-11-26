from "mocha-matvec" import *;

function lc_filter(didLoad) -> null {
    var a: int[] = [1, 2, 3, 4];
    var b: int[] = [x * 2 if x > 1 for each x in a];
    print(b.length, newLine=true);
    print(b[0], newLine=true);
};
