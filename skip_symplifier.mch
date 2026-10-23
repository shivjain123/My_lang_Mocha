from "mocha-SymCha" import *;

function main(didLoad) -> null {
    var x: Expr = var_e("x");
    var ratio: Expr = div_e(sym_diff(ln_e(x), "x"), sym_diff(div_e(num(1.0), x), "x"));
    print("at 0.001:       ", sym_eval(ratio, "x", 0.001), "\n");
    print("at 0.000000001: ", sym_eval(ratio, "x", 0.000000001), "\n");
};