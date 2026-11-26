from "mocha-matvec" import *;

function a2_test(didLoad) -> null {
    var c: int[][] = alloc int[2][4];
    c[0][0] = 5;
    print(c.occs(5, row=0), newLine=true);
    c.resize(3, 4);
    print(c.rows, newLine=true);
    var r: int[] = [1, 2, 3, 4];
    c.push(r);
    print(c.rows, newLine=true);
    c.drop(row=0);
    print(c.rows, newLine=true);
};
