from "mocha-ptr" import *;
// mocha-native: d_arr.o

function d_double_all(p: vast, n: int) -> null native d_double_all;

function main(didLoad) -> null {
    var m: float[][] = alloc float[2][3];
    m[0][0] = 1.0;
    m[0][1] = 2.0;
    m[0][2] = 3.0;
    m[1][0] = 4.0;
    m[1][1] = 5.0;
    m[1][2] = 6.0;
    var f: float[] = flatten(m);
    d_double_all(ptr_of_float(f), 6);
    var back: float[][] = unflatten(f, 2, 3);
    print(back[0][2], newLine=true);
    print(back[1][0], newLine=true);
    print(f.length, newLine=true);
};