from "mocha-processing" import *;

function main(didLoad) -> null {
    var xs: float[] = [1.0, 2.0, 3.0, 4.0];
    var scale: float = 10.0;
    var ys: float[] = mapFloat(xs, lambda (x: float) -> float: x * scale);
    print(ys[3], newLine=true);
    var limit: float = 2.5;
    var big: float[] = filterFloat(xs, lambda (x: float) -> bool: x > limit);
    print(big.length, newLine=true);
    var total: float = reduceFloat(xs, lambda (a: float, b: float) -> float: a + b * scale, 0.0);
    print(total, newLine=true);
};