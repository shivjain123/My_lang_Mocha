from "mocha-matvec" import *;

function run(didLoad) {
    var m: float[][] = alloc float[2][2];
    m[0][0] = 2.0;
    m[0][1] = 0.0;
    m[1][0] = 0.0;
    m[1][1] = 3.0;
    var v: Complex[][] = m.eigenvectors();
    var i: int = 0;
    var total: float = 0.0;
    while (i < 50000) {
        v = m.eigenvectors();
        total = total + v[0][1].real + v[1][0].real;
        i++;
    };
    print("total, expect 100000.0", newLine=true);
    print(total, newLine=true);
};