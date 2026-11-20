from "mocha-ptr" import *;
// mocha-native: d_arr.o

function d_sum(p: vast, n: int) -> float native d_sum;

function main(didLoad) -> null {
    var a: float[] = alloc float[4];
    a[0] = 1.0;
    a[1] = 2.0;
    a[2] = 3.0;
    a[3] = 4.0;
    print(d_sum(ptr_of_float(a), 4), newLine=true);
};