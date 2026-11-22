from "mocha-forge" import *;

function main(didLoad) -> null {
    var xtr: float[][] = [[7.0, 3.2], [6.4, 3.2], [6.9, 3.1], [5.5, 2.3], [6.5, 2.8], [5.7, 2.8], [6.3, 3.3], [4.9, 2.4], [6.6, 2.9], [5.2, 2.7], [5.0, 2.0], [5.9, 3.0], [6.0, 2.2], [6.1, 2.9], [5.6, 2.9], [6.7, 3.1], [5.6, 3.0], [5.8, 2.7], [6.2, 2.2], [5.6, 2.5], [6.3, 3.3], [5.8, 2.7], [7.1, 3.0], [6.3, 2.9], [6.5, 3.0], [7.6, 3.0], [4.9, 2.5], [7.3, 2.9], [6.7, 2.5], [7.2, 3.6], [6.5, 3.2], [6.4, 2.7], [6.8, 3.0], [5.7, 2.5], [5.8, 2.8], [6.4, 3.2], [6.5, 3.0], [7.7, 3.8], [7.7, 2.6], [6.0, 2.2]];
    var ytr: int[] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
    var xte: float[][] = [[5.9, 3.2], [6.1, 2.8], [6.3, 2.5], [6.1, 2.8], [6.4, 2.9], [6.9, 3.2], [5.6, 2.8], [7.7, 2.8], [6.3, 2.7], [6.7, 3.3]];
    var yte: int[] = [0, 0, 0, 0, 0, 1, 1, 1, 1, 1];

    var lg: LogisticClassification = LogisticClassification(0.1, 100000);
    lg.fit(xtr, ytr);

    // weights and bias
    print(lg.weights[0], newLine=true);
    print(lg.weights[1], newLine=true);
    print(lg.bias, newLine=true);

    // probabilities on the 10 test rows
    var pr: float[] = lg.predict_probab(xte);
    var i: int = 0;
    while (i < pr.length) {
        print(pr[i], newLine=true);
        i++;
    };

    // class predictions
    var pc: int[] = lg.predict(xte);
    var j: int = 0;
    while (j < pc.length) {
        print(pc[j], newLine=true);
        j++;
    };

    // metrics
    print(lg.accuracy(xte, yte), newLine=true);
    print(lg.precision(xte, yte), newLine=true);
    print(lg.recall(xte, yte), newLine=true);
    print(lg.f1(xte, yte), newLine=true);
};