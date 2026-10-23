from "mocha-SymCha" import *;

function main(didLoad) -> null {
    var x: Expr = var_e("x");
    print("A: ln(0)\n");
    print(sym_eval(ln_e(x), "x", 0.0), "\n");
    var rw: Expr = div_e(x, div_e(num(1.0), ln_e(x)));
    print("B: rewritten form at 0\n");
    print(sym_eval(rw, "x", 0.0), "\n");
    print("C: derivative of 1/ln(x)\n");
    print(sym_print(sym_diff(div_e(num(1.0), ln_e(x)), "x")), "\n");
    print("D: done\n");
};