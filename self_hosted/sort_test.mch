from "mocha-matvec" import *;

function sort_test(didLoad) -> null {
    var a: int[] = [3, 1, 2];
    a.sort();
    print(a[0], newLine=true);
    print(a[2], newLine=true);
    var b: int[] = [3, 1, 2];
    b.sort(lambda(x: int, y: int) -> bool: x > y);
    print(b[0], newLine=true);
    print(b[2], newLine=true);
};
