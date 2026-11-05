from "mocha-matvec" import *;

function run(didLoad) {
    var a: Complex[] = alloc Complex[1];
    a[0] = Complex(3.0, 4.0);
    print("1: norm of 3+4im, expect 5.0", newLine=true);
    print(complex_norm(a), newLine=true);

    var b: Complex[] = alloc Complex[1];
    b[0] = Complex(10000000000.0, 0);
    print("2: norm of 1e10, expect 10000000000.0", newLine=true);
    print(complex_norm(b), newLine=true);

    var c: Complex[] = alloc Complex[1];
    c[0] = Complex(0.00000001, 0);
    print("3: norm of 1e-8, expect 1e-08", newLine=true);
    print(complex_norm(c), newLine=true);
};