from "mocha-forge" import *;

function main(didLoad) -> null {
    var x: float[][] = alloc float[8][2];
    x[0][0] = 1.0; x[0][1] = 1.0;
    x[1][0] = 2.0; x[1][1] = 2.0;
    x[2][0] = 3.0; x[2][1] = 3.0;
    x[3][0] = 4.0; x[3][1] = 4.0;
    x[4][0] = 5.0; x[4][1] = 5.0;
    x[5][0] = 6.0; x[5][1] = 6.0;
    x[6][0] = 7.0; x[6][1] = 7.0;
    x[7][0] = 8.0; x[7][1] = 8.0;

    var y: int[] = alloc int[8];
    y[0] = 0; y[1] = 0; y[2] = 0; y[3] = 0;
    y[4] = 1; y[5] = 1; y[6] = 1; y[7] = 1;

    // train and save
    var dt: DecisionTree = DecisionTree(4);
    dt.fit(x, y);
    print("before save accuracy=" + str(dt.accuracy(x, y)), newLine=true);
    dt.save("dt_model.db");

    // load into fresh model
    var dt2: DecisionTree = DecisionTree(4);
    dt2.load("dt_model.db");
    print("after load accuracy=" + str(dt2.accuracy(x, y)), newLine=true);

    // predictions should match
    var p1: int[] = dt.predict(x);
    var p2: int[] = dt2.predict(x);
    var i: int = 0;
    while (i < 8) {
        print("orig=" + str(p1[i]) + " loaded=" + str(p2[i]), newLine=true);
        i++;
    };
};