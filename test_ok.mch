// mocha-native: ..\..\blas_ref\BLAS-3.12.0\libblas.a, @fortran
from "mocha-ptr" import *;

function blas_dgemm(ta: str, tb: str, m: vast, n: vast, k: vast, alpha: vast, a: vast, lda: vast, b: vast, ldb: vast, beta: vast, c: vast, ldc: vast) -> null native dgemm_;

function one_int(v: int) -> int[] {
    var o: int[] = alloc int[1];
    o[0] = v;
    return o;
};

function one_float(v: float) -> float[] {
    var o: float[] = alloc float[1];
    o[0] = v;
    return o;
};

function main(didLoad) -> null {
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

    var af: float[] = flatten(am);
    var bf: float[] = flatten(bm);
    var cf: float[] = alloc float[8];

    var pm: int[] = one_int(4);
    var pn: int[] = one_int(2);
    var pk: int[] = one_int(3);
    var plda: int[] = one_int(4);
    var pldb: int[] = one_int(3);
    var pldc: int[] = one_int(4);
    var palpha: float[] = one_float(1.0);
    var pbeta: float[] = one_float(0.0);

    blas_dgemm("N", "N", ptr_of_int(pm), ptr_of_int(pn), ptr_of_int(pk), ptr_of_float(palpha), ptr_of_float(bf), ptr_of_int(plda), ptr_of_float(af), ptr_of_int(pldb), ptr_of_float(pbeta), ptr_of_float(cf), ptr_of_int(pldc));

    var cm: float[][] = unflatten(cf, 2, 4);
    print(cm[0][0], newLine=true);
    print(cm[0][3], newLine=true);
    print(cm[1][0], newLine=true);
    print(cm[1][3], newLine=true);
};