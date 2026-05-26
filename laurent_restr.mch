from "mocha-SymCha" import *;

function laurentify(didLoad){
    // sinc function: sin(x)/x — pole of order 1 at x=0
    var sinc: Expr = div_e(sin_e(var_e("x")), var_e("x"));
    var l1: Expr = sym_laurent(sinc, "x", 5);
    print(sym_print(l1), newLine=true);
    // expected: 1 - x²/6 + x⁴/120 ...

    // 1/x² — pure pole
    var inv_x2: Expr = div_e(num(1.0), pow_e(var_e("x"), num(2.0)));
    var l2: Expr = sym_laurent(inv_x2, "x", 3);
    print(sym_print(l2), newLine=true);
    // expected: x⁻² + 0 + 0...

    // cos(x)/x — order 1 pole
    var cosx_over_x: Expr = div_e(cos_e(var_e("x")), var_e("x"));
    var l3: Expr = sym_laurent(cosx_over_x, "x", 4);
    print(sym_print(l3), newLine=true);
    // expected: x⁻¹ - x/2 + x³/24...
};