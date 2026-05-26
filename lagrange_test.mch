from "mocha-SymCha" import *;

function main(didLoad){
    // Points: (0,1), (1,2), (2,5) → should give x² + 1
   var xs: float[] = [0.0, 1.0, 2.0];
var ys: float[] = [1.0, 2.0, 5.0];
var poly: Expr = sym_lagrange(xs, ys, 3, "x");
print(sym_eval(poly, "x", 0.0), newLine=true);  // should be 1.0
print(sym_eval(poly, "x", 1.0), newLine=true);  // should be 2.0
print(sym_eval(poly, "x", 2.0), newLine=true);  // should be 5.0
print(sym_eval(poly, "x", 1.5), newLine=true);  // interpolated value
};