from "mocha-math" import *;
from "mocha-matvec" import *;

function test(didLoad) -> null {

    var a: float[][] = [[4.0, 1.0], [2.0, 3.0]];
    var n: int = 3;

    // Eigendecomposition — a = p * d * p^-1
    var evals: float[] = a.eigenvalues();
    var evecs: float[][] = a.eigenvectors();
    var p: float[][] = evecs;
    var Pinv: float[][] = p.inverse();

    // d^n — diagonal matrix with eigenvalues raised to power n
    var l1n: float = fast_pow(evals[0], n);
    var l2n: float = fast_pow(evals[1], n);
    var dn: float[][] = [[l1n, 0.0], [0.0, l2n]];

    // a^n = p * d^n * p^-1
    var result: float[][] = p.vector(dn).vector(Pinv);

    // Print result matrix
    print(result[0][0], newLine=true);
    print(result[0][1], newLine=true);
    print(result[1][0], newLine=true);
    print(result[1][1], newLine=true);
};