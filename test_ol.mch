// mocha-native: ..\..\blas_ref\BLAS-3.12.0\libblas.a, @fortran
from "mocha-matvec" import *;
from "mocha-blas" import *;

function main(didLoad) -> null {
    var x: float[] = [];
    x.push(1.0);
    x.push(2.0);
    x.push(3.0);
    var y: float[] = [];
    y.push(4.0);
    y.push(5.0);
    y.push(6.0);

    print(blas_dot(x, y), newLine=true);
    print(x.vector(y), newLine=true);
    print(blas_norm(x), newLine=true);

    var z: float[] = blas_axpy(2.0, x, y);
    print(z[1], newLine=true);
    var s: float[] = blas_scale(3.0, x);
    print(s[2], newLine=true);
    print(x[2], newLine=true);

    var am: float[][] = alloc float[2][3];
    var bm: float[][] = alloc float[3][4];
    var r: int = 0;
    while (r < 2) {
        var c: int = 0;
        while (c < 3) {
            am[r][c] = float(r * 3 + c + 1);
            c++;
        };
        r++;
    };
    r = 0;
    while (r < 3) {
        var c: int = 0;
        while (c < 4) {
            bm[r][c] = float(r * 4 + c + 1);
            c++;
        };
        r++;
    };

    var c1: float[][] = blas_matmul(am, bm);
    var c2: float[][] = am.vector(bm);
    print(c1[0][0], newLine=true);
    print(c1[1][3], newLine=true);
    print(c2[1][3], newLine=true);
};