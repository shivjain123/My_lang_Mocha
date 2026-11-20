// mocha-native: ..\..\blas_ref\BLAS-3.12.0\libblas.a, @fortran
from "mocha-ptr" import *;

function blas_ddot(n: vast, x: vast, incx: vast, y: vast, incy: vast) -> float native ddot_;
function blas_dnrm2(n: vast, x: vast, incx: vast) -> float native dnrm2_;
function blas_daxpy(n: vast, a: vast, x: vast, incx: vast, y: vast, incy: vast) -> null native daxpy_;

function main(didLoad) -> null {
    var n: int[] = alloc int[1];
    var one: int[] = alloc int[1];
    var alpha: float[] = alloc float[1];
    n[0] = 3;
    one[0] = 1;
    alpha[0] = 2.0;

    var x: float[] = alloc float[3];
    var y: float[] = alloc float[3];
    x[0] = 1.0;
    x[1] = 2.0;
    x[2] = 3.0;
    y[0] = 4.0;
    y[1] = 5.0;
    y[2] = 6.0;

    print(blas_ddot(ptr_of_int(n), ptr_of_float(x), ptr_of_int(one), ptr_of_float(y), ptr_of_int(one)), newLine=true);
    print(blas_dnrm2(ptr_of_int(n), ptr_of_float(x), ptr_of_int(one)), newLine=true);
    blas_daxpy(ptr_of_int(n), ptr_of_float(alpha), ptr_of_float(x), ptr_of_int(one), ptr_of_float(y), ptr_of_int(one));
    print(y[0], newLine=true);
    print(y[2], newLine=true);
};