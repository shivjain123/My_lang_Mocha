from "mocha-math" import *;

function test(didLoad) -> null {

    // sinh
    var s1: float = (0.0).sinh();
    print(s1, newLine=true);

    var s2: float = (1.0).sinh();
    print(s2, newLine=true);

    // cosh
    var c1: float = (0.0).cosh();
    print(c1, newLine=true);

    var c2: float = (1.0).cosh();
    print(c2, newLine=true);

    // tanh
    var t1: float = (0.0).tanh();
    print(t1, newLine=true);

    var t2: float = (1.0).tanh();
    print(t2, newLine=true);

    // inv_sinh
    var is1: float = (0.0).inv_sinh();
    print(is1, newLine=true);

    var is2: float = (1.1752).inv_sinh();
    print(is2, newLine=true);

    // inv_cosh — real for x >= 1
    var ic1: Complex = (1.0).inv_cosh();
    print(ic1.real, newLine=true);
    print(ic1.imag, newLine=true);
    // Expected: 0.0, 0.0

    var ic2: Complex = (2.0).inv_cosh();
    print(ic2.real, newLine=true);
    print(ic2.imag, newLine=true);
    // Expected: 1.3169, 0.0

    // inv_cosh — complex for x < 1
    var ic3: Complex = (0.0).inv_cosh();
    print(ic3.real, newLine=true);
    print(ic3.imag, newLine=true);
    // Expected: 0.0, 1.5708

    // inv_tanh
    var it1: float = (0.0).inv_tanh();
    print(it1, newLine=true);

    var it2: float = (0.5).inv_tanh();
    print(it2, newLine=true);

    // inv_tanh boundary
    var it3: float = (1.0).inv_tanh();
    print(it3, newLine=true);
    // Expected: Inf

};