from "mocha-forge" import *;

function main(didLoad) -> null {
    var xtr: float[][] = [[7.0, 3.2, 4.7, 1.4], [6.4, 3.2, 4.5, 1.5], [6.9, 3.1, 4.9, 1.5], [5.5, 2.3, 4.0, 1.3], [6.5, 2.8, 4.6, 1.5], [5.7, 2.8, 4.5, 1.3], [6.3, 3.3, 4.7, 1.6], [4.9, 2.4, 3.3, 1.0], [6.6, 2.9, 4.6, 1.3], [5.2, 2.7, 3.9, 1.4], [5.0, 2.0, 3.5, 1.0], [5.9, 3.0, 4.2, 1.5], [6.0, 2.2, 4.0, 1.0], [6.1, 2.9, 4.7, 1.4], [5.6, 2.9, 3.6, 1.3], [6.7, 3.1, 4.4, 1.4], [5.6, 3.0, 4.5, 1.5], [5.8, 2.7, 4.1, 1.0], [6.2, 2.2, 4.5, 1.5], [5.6, 2.5, 3.9, 1.1], [6.3, 3.3, 6.0, 2.5], [5.8, 2.7, 5.1, 1.9], [7.1, 3.0, 5.9, 2.1], [6.3, 2.9, 5.6, 1.8], [6.5, 3.0, 5.8, 2.2], [7.6, 3.0, 6.6, 2.1], [4.9, 2.5, 4.5, 1.7], [7.3, 2.9, 6.3, 1.8], [6.7, 2.5, 5.8, 1.8], [7.2, 3.6, 6.1, 2.5], [6.5, 3.2, 5.1, 2.0], [6.4, 2.7, 5.3, 1.9], [6.8, 3.0, 5.5, 2.1], [5.7, 2.5, 5.0, 2.0], [5.8, 2.8, 5.1, 2.4], [6.4, 3.2, 5.3, 2.3], [6.5, 3.0, 5.5, 1.8], [7.7, 3.8, 6.7, 2.2], [7.7, 2.6, 6.9, 2.3], [6.0, 2.2, 5.0, 1.5]];
    var ytr: int[] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
    var xte: float[][] = [[5.9, 3.2, 4.8, 1.8], [6.1, 2.8, 4.0, 1.3], [6.3, 2.5, 4.9, 1.5], [6.1, 2.8, 4.7, 1.2], [6.4, 2.9, 4.3, 1.3], [6.9, 3.2, 5.7, 2.3], [5.6, 2.8, 4.9, 2.0], [7.7, 2.8, 6.7, 2.0], [6.3, 2.7, 4.9, 1.8], [6.7, 3.3, 5.7, 2.1]];
    var yte: int[] = [0, 0, 0, 0, 0, 1, 1, 1, 1, 1];

    // depth 2, entropy: the 10 predictions
    var d2: DecisionTree = DecisionTree(2);
    d2.fit(xtr, ytr);
    var p2: int[] = d2.predict(xte);
    var i: int = 0;
    while (i < p2.length) {
        print(p2[i], newLine=true);
        i++;
    };

    // depth 3, entropy: test accuracy, precision, recall, f1, then train accuracy
    var d3: DecisionTree = DecisionTree(3);
    d3.fit(xtr, ytr);
    print(d3.accuracy(xte, yte), newLine=true);
    print(d3.precision(xte, yte), newLine=true);
    print(d3.recall(xte, yte), newLine=true);
    print(d3.f1(xte, yte), newLine=true);
    print(d3.accuracy(xtr, ytr), newLine=true);

    // depth 10, entropy: test accuracy
    var d10: DecisionTree = DecisionTree(10);
    d10.fit(xtr, ytr);
    print(d10.accuracy(xte, yte), newLine=true);

    // depth 3, gini: test accuracy and precision
    var dg: DecisionTree = DecisionTree(3);
    dg.fast_gini();
    dg.fit(xtr, ytr);
    print(dg.accuracy(xte, yte), newLine=true);
    print(dg.precision(xte, yte), newLine=true);
};