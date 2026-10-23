from "mocha-SymCha" import *;

function main(didLoad) -> null {
    var x: Expr = var_e("x");
    var top: Expr = ln_e(x);
    var bottom: Expr = div_e(num(1.0), x);
    var dtop: Expr = sym_diff(top, "x");
    var dbottom: Expr = sym_diff(bottom, "x");
    print("d(top):    ", sym_print(dtop), "\n");
    print("d(bottom): ", sym_print(dbottom), "\n");
    var ratio: Expr = div_e(dtop, dbottom);
    print("ratio simplified: ", sym_print(sym_simplify_full(ratio)), "\n");
};