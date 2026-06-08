from "mocha-forge" import *;

"""function main(didLoad) -> null {
    // simple dataset: y = x1 + x2 (linear relationship, GB should handle easily)
    var x: float[][] = alloc float[6][2];
    x[0][0] = 1.0; x[0][1] = 1.0;
    x[1][0] = 2.0; x[1][1] = 2.0;
    x[2][0] = 3.0; x[2][1] = 3.0;
    x[3][0] = 4.0; x[3][1] = 4.0;
    x[4][0] = 5.0; x[4][1] = 5.0;
    x[5][0] = 6.0; x[5][1] = 6.0;

    var y: float[] = alloc float[6];
    y[0] = 2.0;
    y[1] = 4.0;
    y[2] = 6.0;
    y[3] = 8.0;
    y[4] = 10.0;
    y[5] = 12.0;

    var gb: GradientBoosting = GradientBoosting(50, 3, 0.1, 0.8);
    gb.fit(x, y);

    var preds: float[] = gb.predict(x);
    var i: int = 0;
    while (i < 6) {
        print("y=" + str(y[i]) + " pred=" + str(preds[i]), newLine=true);
        i++;
    };
};"""

function main(didLoad) -> null {
    // simple dataset: class 1 if x1 + x2 > 6, else 0
    var x: float[][] = alloc float[8][2];
    x[0][0] = 1.0; x[0][1] = 1.0;
    x[1][0] = 2.0; x[1][1] = 2.0;
    x[2][0] = 3.0; x[2][1] = 3.0;
    x[3][0] = 4.0; x[3][1] = 4.0;
    x[4][0] = 5.0; x[4][1] = 2.0;
    x[5][0] = 6.0; x[5][1] = 2.0;
    x[6][0] = 7.0; x[6][1] = 1.0;
    x[7][0] = 8.0; x[7][1] = 1.0;

    var y: int[] = alloc int[8];
    y[0] = 0;
    y[1] = 0;
    y[2] = 0;
    y[3] = 1;
    y[4] = 1;
    y[5] = 1;
    y[6] = 1;
    y[7] = 1;

    var gb: GradientBoosting = GradientBoosting(50, 3, 0.1, 0.8);
    gb.fit(x, y);

    var preds: int[] = gb.predict_class(x);
    var i: int = 0;
    while (i < 8) {
        print("y=" + str(y[i]) + " pred=" + str(preds[i]), newLine=true);
        i++;
    };

    print("accuracy=" + str(gb.accuracy(x, y)), newLine=true);
};