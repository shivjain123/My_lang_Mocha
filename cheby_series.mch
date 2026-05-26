from "mocha-SymCha" import *;

function cheb(didLoad){
    // Approximate e^x on [-1,1] with 5 terms
    var f: Expr = exp_e(var_e("x"));
    var cheb: Expr = sym_chebyshev(f, "x", 5);
    print(sym_print(cheb), newLine=true);
    print(sym_eval(cheb, "x", 0.5), newLine=true);   // e^0.5 ≈ 1.64872
    print(sym_eval(cheb, "x", -0.5), newLine=true);  // e^-0.5 ≈ 0.60653

    // Compare with Taylor
    var taylor: Expr = sym_taylor(exp_e(var_e("x")), "x", 0.0, 5);
    print(sym_eval(taylor, "x", 0.5), newLine=true);
    print(sym_eval(taylor, "x", -0.5), newLine=true);
};