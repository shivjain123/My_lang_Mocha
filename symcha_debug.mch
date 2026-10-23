from "mocha-SymCha" import *;

function main(didLoad) -> null {
    var x: Expr = var_e("x");
    var top: Expr = sub(exp_e(x), num(1.0));
    print("exp(0) = ", sym_eval(exp_e(x), "x", 0.0), "\n");
    print("exp(0)-1 = ", sym_eval(top, "x", 0.0), "\n");
    var dtop: Expr = sym_diff(top, "x");
    print("derivative: ", sym_print(dtop), "\n");
    print("derivative at 0 = ", sym_eval(dtop, "x", 0.0), "\n");
};