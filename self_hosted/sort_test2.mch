from "mocha-matvec" import *;

function sort_test2(didLoad) -> null {
    var a: int[] = [3, 1, 2];
    a.sort();
    print(a[0], newLine=true);
    var b: int[] = [3, 1, 2];
    sort(b);
    print(b[0], newLine=true);
    var c: int[] = [3, 1, 2];
    sort(c, lambda(x: int, y: int) -> bool: x > y);
    print(c[0], newLine=true);
    var d: int[] = [3, 1, 2];
    d.sort(lambda(x: int, y: int) -> bool: x > y);
    print(d[0], newLine=true);
};
