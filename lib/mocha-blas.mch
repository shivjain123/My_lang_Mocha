// mocha-lib-deps: mocha-ptr
"""
mocha-blas v0.1 — fast vector and matrix operations through BLAS

You must link a BLAS library in your own program (this library does not ship one):
    // mocha-native: path\to\libblas.a, @fortran

Functions (all return new arrays and never change their inputs):
  blas_dot(x, y)        — dot product of two float[] (same length)
  blas_norm(x)          — length of a float[]
  blas_axpy(a, x, y)    — a * x + y, element by element
  blas_scale(a, x)      — a * x
  blas_matmul(a, b)     — matrix product of two float[][] (a.cols must equal b.rows)
"""

// ---- raw BLAS entry points (Fortran: every argument is passed by pointer) ----
local function blas_raw_ddot(n: vast, x: vast, incx: vast, y: vast, incy: vast) -> float native ddot_;
local function blas_raw_dnrm2(n: vast, x: vast, incx: vast) -> float native dnrm2_;
local function blas_raw_daxpy(n: vast, a: vast, x: vast, incx: vast, y: vast, incy: vast) -> null native daxpy_;
local function blas_raw_dscal(n: vast, a: vast, x: vast, incx: vast) -> null native dscal_;
local function blas_raw_dgemm(ta: str, tb: str, m: vast, n: vast, k: vast, alpha: vast, a: vast, lda: vast, b: vast, ldb: vast, beta: vast, c: vast, ldc: vast) -> null native dgemm_;

// ---- small helpers ----
local function blas_one_int(v: int) -> int[] {
    var o: int[] = alloc int[1];
    o[0] = v;
    return o;
};

local function blas_one_float(v: float) -> float[] {
    var o: float[] = alloc float[1];
    o[0] = v;
    return o;
};

// copy any float[] (even a growing one) into a fixed-size array, which ptr_of_float accepts
local function blas_fixed(x: float[]) -> float[] {
    var out: float[] = alloc float[x.length];
    var i: int = 0;
    while (i < x.length) {
        out[i] = x[i];
        i++;
    };
    return out;
};

// ---- public API ----
function blas_dot(x: float[], y: float[]) -> float {
    if (x.length != y.length) {
        fail "blas_dot: the two vectors must have the same length";
    };
    if (x.length == 0) {
        return 0.0;
    };
    var xf: float[] = blas_fixed(x);
    var yf: float[] = blas_fixed(y);
    var n: int[] = blas_one_int(x.length);
    var one: int[] = blas_one_int(1);
    return blas_raw_ddot(ptr_of_int(n), ptr_of_float(xf), ptr_of_int(one), ptr_of_float(yf), ptr_of_int(one));
};

function blas_norm(x: float[]) -> float {
    if (x.length == 0) {
        return 0.0;
    };
    var xf: float[] = blas_fixed(x);
    var n: int[] = blas_one_int(x.length);
    var one: int[] = blas_one_int(1);
    return blas_raw_dnrm2(ptr_of_int(n), ptr_of_float(xf), ptr_of_int(one));
};

function blas_axpy(alpha: float, x: float[], y: float[]) -> float[] {
    if (x.length != y.length) {
        fail "blas_axpy: the two vectors must have the same length";
    };
    var yf: float[] = blas_fixed(y);
    if (x.length == 0) {
        return yf;
    };
    var xf: float[] = blas_fixed(x);
    var n: int[] = blas_one_int(x.length);
    var one: int[] = blas_one_int(1);
    var pa: float[] = blas_one_float(alpha);
    blas_raw_daxpy(ptr_of_int(n), ptr_of_float(pa), ptr_of_float(xf), ptr_of_int(one), ptr_of_float(yf), ptr_of_int(one));
    return yf;
};

function blas_scale(alpha: float, x: float[]) -> float[] {
    var xf: float[] = blas_fixed(x);
    if (x.length == 0) {
        return xf;
    };
    var n: int[] = blas_one_int(x.length);
    var one: int[] = blas_one_int(1);
    var pa: float[] = blas_one_float(alpha);
    blas_raw_dscal(ptr_of_int(n), ptr_of_float(pa), ptr_of_float(xf), ptr_of_int(one));
    return xf;
};

// Row-major C = A * B computed as column-major C^T = B^T * A^T, so B goes in first.
function blas_matmul(a: float[][], b: float[][]) -> float[][] {
    var m: int = a.rows;
    var k: int = a.cols;
    var n: int = b.cols;
    if (b.rows != k) {
        fail "blas_matmul: a.cols must equal b.rows";
    };
    if (m == 0 || n == 0 || k == 0) {
        var zero: float[][] = alloc float[m][n];
        return zero;
    };
    var af: float[] = flatten(a);
    var bf: float[] = flatten(b);
    var cf: float[] = alloc float[m * n];
    var pm: int[] = blas_one_int(n);
    var pn: int[] = blas_one_int(m);
    var pk: int[] = blas_one_int(k);
    var plda: int[] = blas_one_int(n);
    var pldb: int[] = blas_one_int(k);
    var pldc: int[] = blas_one_int(n);
    var palpha: float[] = blas_one_float(1.0);
    var pbeta: float[] = blas_one_float(0.0);
    blas_raw_dgemm("N", "N", ptr_of_int(pm), ptr_of_int(pn), ptr_of_int(pk), ptr_of_float(palpha), ptr_of_float(bf), ptr_of_int(plda), ptr_of_float(af), ptr_of_int(pldb), ptr_of_float(pbeta), ptr_of_float(cf), ptr_of_int(pldc));
    return unflatten(cf, m, n);
};