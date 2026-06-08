from "mocha-forge" import *;

function main(didLoad) -> null {
    rand_seed(42);

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

    var gb: GradientBoosting = GradientBoosting(50, 3, 0.1, 0.8);
    gb.fit(x, y);
    print("before save accuracy=" + str(gb.accuracy(x, y)), newLine=true);
    gb.save("gb_model.db");

    var gb2: GradientBoosting = GradientBoosting(50, 3, 0.1, 0.8);
    gb2.load("gb_model.db");
    print("after load accuracy=" + str(gb2.accuracy(x, y)), newLine=true);

    var p1: int[] = gb.predict_class(x);
    var p2: int[] = gb2.predict_class(x);
    var i: int = 0;
    while (i < 8) {
        print("orig=" + str(p1[i]) + " loaded=" + str(p2[i]), newLine=true);
        i++;
    };
};