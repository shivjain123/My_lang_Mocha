from "mocha-matvec" import *;

function index_tests(didLoad) -> null {
    var a: int[] = [1, 2, 3];
    a[1] = 20;
    var f: float[] = [1.5, 2.5];
    f[0] = 3.5;
    var s: str[] = ["x", "y"];
    s[1] = "z";
    print(str(a[1]) + " " + str(f[0]) + " " + s[1], newLine=true);
};
