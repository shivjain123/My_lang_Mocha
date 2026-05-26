from "mocha-SymCha" import *;

function main(didLoad){
    var pi: float = 3.14159265358979;
var f: Expr = var_e("x");
var series: Expr = sym_fourier(f, "x", pi, 5);
print(sym_print(series), newLine=true);
print(sym_eval(series, "x", 1.0), newLine=true);  // should be ≈ 1.0
print(sym_eval(series, "x", 2.0), newLine=true);  // should be ≈ 2.0
};