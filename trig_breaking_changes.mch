from "mocha-SymCha" import *;

function main(didLoad){
    var x: Expr = var_e("x");
    print(sym_print(sym_diff(tan_e(x), "x")), newLine=true);   // 1/cos²(x)
    print(sym_print(sym_diff(sinh_e(x), "x")), newLine=true);  // cosh(x)
    print(sym_print(sym_diff(atan_e(x), "x")), newLine=true);  // 1/(1 + x²)
    print(sym_eval(tanh_e(x), "x", 0.0), newLine=true);        // 0.0
};