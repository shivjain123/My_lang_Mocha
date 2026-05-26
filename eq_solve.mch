from "mocha-SymCha" import *;

function main(didLoad){
    // solve x² - 2 = 0  → should give √2 ≈ 1.41421
    var eq: Expr = sub(pow_e(var_e("x"), num(2.0)), num(2.0));
    var root: float = sym_solve(eq, "x", 1.0);

    print("Root is: ", root, newLine=true);
};