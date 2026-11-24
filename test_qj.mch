from "mocha-forge" import *;

function main(didLoad) -> null {
    var xtr: float[][] = [[7.0, 3.2, 4.7, 1.4], [6.4, 3.2, 4.5, 1.5], [6.9, 3.1, 4.9, 1.5], [5.5, 2.3, 4.0, 1.3], [6.5, 2.8, 4.6, 1.5], [5.7, 2.8, 4.5, 1.3], [6.3, 3.3, 4.7, 1.6], [4.9, 2.4, 3.3, 1.0], [6.6, 2.9, 4.6, 1.3], [5.2, 2.7, 3.9, 1.4], [5.0, 2.0, 3.5, 1.0], [5.9, 3.0, 4.2, 1.5], [6.0, 2.2, 4.0, 1.0], [6.1, 2.9, 4.7, 1.4], [5.6, 2.9, 3.6, 1.3], [6.7, 3.1, 4.4, 1.4], [5.6, 3.0, 4.5, 1.5], [5.8, 2.7, 4.1, 1.0], [6.2, 2.2, 4.5, 1.5], [5.6, 2.5, 3.9, 1.1], [6.3, 3.3, 6.0, 2.5], [5.8, 2.7, 5.1, 1.9], [7.1, 3.0, 5.9, 2.1], [6.3, 2.9, 5.6, 1.8], [6.5, 3.0, 5.8, 2.2], [7.6, 3.0, 6.6, 2.1], [4.9, 2.5, 4.5, 1.7], [7.3, 2.9, 6.3, 1.8], [6.7, 2.5, 5.8, 1.8], [7.2, 3.6, 6.1, 2.5], [6.5, 3.2, 5.1, 2.0], [6.4, 2.7, 5.3, 1.9], [6.8, 3.0, 5.5, 2.1], [5.7, 2.5, 5.0, 2.0], [5.8, 2.8, 5.1, 2.4], [6.4, 3.2, 5.3, 2.3], [6.5, 3.0, 5.5, 1.8], [7.7, 3.8, 6.7, 2.2], [7.7, 2.6, 6.9, 2.3], [6.0, 2.2, 5.0, 1.5]];
    var ytr: int[] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
    var xte: float[][] = [[5.9, 3.2, 4.8, 1.8], [6.1, 2.8, 4.0, 1.3], [6.3, 2.5, 4.9, 1.5], [6.1, 2.8, 4.7, 1.2], [6.4, 2.9, 4.3, 1.3], [6.9, 3.2, 5.7, 2.3], [5.6, 2.8, 4.9, 2.0], [7.7, 2.8, 6.7, 2.0], [6.3, 2.7, 4.9, 1.8], [6.7, 3.3, 5.7, 2.1]];
    var yte: int[] = [0, 0, 0, 0, 0, 1, 1, 1, 1, 1];

    var rf: RandomForest = RandomForest(25, 4);
    rf.fit(xtr, ytr);
    var p1: int[] = rf.predict(xte);
    print(rf.accuracy(xte, yte), newLine=true);
    print(rf.accuracy(xtr, ytr), newLine=true);

    // a second forest with the same settings must give identical predictions
    var rf2: RandomForest = RandomForest(25, 4);
    rf2.fit(xtr, ytr);
    var p2: int[] = rf2.predict(xte);
    var same_fit: int = 1;
    var i: int = 0;
    while (i < p1.length) {
        if (p1[i] != p2[i]) { same_fit = 0; };
        i++;
    };
    print(same_fit, newLine=true);

    // save, load into a fresh forest, predictions must be identical
    rf.save("rf_test.db");
    var rf3: RandomForest = RandomForest(1, 1);
    rf3.load("rf_test.db");
    var p3: int[] = rf3.predict(xte);
    var same_load: int = 1;
    var j: int = 0;
    while (j < p1.length) {
        if (p1[j] != p3[j]) { same_load = 0; };
        j++;
    };
    print(same_load, newLine=true);
    print(rf3.n_trees, newLine=true);
    print(rf3.accuracy(xtr, ytr), newLine=true);
};