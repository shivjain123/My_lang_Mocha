from "mocha-forge" import *;

function test(didLoad) -> null {
    var x: float[][] = alloc float[6][1];
    x[0][0] = 1.0; x[1][0] = 2.0; x[2][0] = 3.0;
    x[3][0] = 5.0; x[4][0] = 6.0; x[5][0] = 7.0;

    var y: int[] = alloc int[6];
    y[0] = 0; y[1] = 0; y[2] = 0;
    y[3] = 1; y[4] = 1; y[5] = 1;

    // linear mode
    var lin: Svm = Svm(1000);
    lin.linear(0.01);
    lin.fit(x, y);
    print("Linear Svm:", newLine=true);
    var lp: int[] = lin.predict(x);
    var i: int = 0;
    while (i < lp.length) { print(str(lp[i]), newLine=true); i++; };
    print("Accuracy: " + str(lin.accuracy(x, y)), newLine=true);

    // rbf mode
    var rbf: Svm = Svm(100);
    rbf.rbf(1.0, 0.5);
    rbf.fit(x, y);
    print("RBF SVM:", newLine=true);
    var rp: int[] = rbf.predict(x);
    var j: int = 0;
    while (j < rp.length) { print(str(rp[j]), newLine=true); j++; };
    print("Accuracy: " + str(rbf.accuracy(x, y)), newLine=true);
    print("F1: " + str(rbf.f1(x, y)), newLine=true);
};