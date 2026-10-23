from "mocha-SymCha" import *;

function main(didLoad) -> null {
    print("T0: ", sym_print(cheby_T_expr(0, "x")), "\n");
    print("T1: ", sym_print(cheby_T_expr(1, "x")), "\n");
    print("T2: ", sym_print(cheby_T_expr(2, "x")), "\n");
    print("T3: ", sym_print(cheby_T_expr(3, "x")), "\n");
};