from "mocha-forge" import *;

function main(didLoad) -> null {
    var x: float[][] = [[0.0, 0.0], [0.1, 0.2], [0.2, 0.1],
                        [5.0, 5.0], [5.1, 4.9], [4.9, 5.2]];
    var y: int[] = [0, 0, 0, 1, 1, 1];
    var t: float[][] = [[0.1, 0.1], [5.0, 5.1], [2.0, 2.0]];

    var a: KNNClassifier = KNNClassifier(3);
    a.fit(x, y);
    var p1: int[] = a.predict(t);
    a.save("knn_load_test.db");

    var b: KNNClassifier = KNNClassifier(3);
    b.load("knn_load_test.db");
    var p2: int[] = b.predict(t);

    var ok: bool = true;
    var i: int = 0;
    while (i < t.length) {
        print("orig=", p1[i], " loaded=", p2[i], newLine=true);
        if (p1[i] != p2[i]) { ok = false; };
        i++;
    };
    if (ok) { print("PASS: loaded model predicts the same", newLine=true); };
    if (!ok) { print("FAIL: predictions differ after load", newLine=true); };
};